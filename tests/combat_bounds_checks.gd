extends RefCounted

func freeze(session) -> void:
	session.world.set_physics_process(false)
	for actor in session.world.actors: actor.set_physics_process(false)

func run(session, check: Callable) -> void:
	check.call(not DamageSystem.critical_roll(0,0) and not DamageSystem.critical_roll(0,1),"zero critical probability never succeeds at RNG endpoints")
	check.call(DamageSystem.critical_roll(1,0) and DamageSystem.critical_roll(1,1),"guaranteed critical probability includes the upper RNG endpoint")
	check.call(DamageSystem.critical_roll(.4,.39) and not DamageSystem.critical_roll(.4,.4),"ordinary critical threshold keeps its previous comparison")
	var duration_stats := StatsComponent.new()
	duration_stats.base = {"status_duration":2}
	var burn: StatusData = Database.statuses["status.burn"]
	check.call(StatusComponent.duration_for(burn,duration_stats,1)==burn.duration+3,"ordinary effect duration retains source and ability bonuses")
	duration_stats.base.status_duration = 3599
	check.call(StatusComponent.duration_for(burn,duration_stats,10)==3600,"combined source and ability bonuses share the duration ceiling")
	var stats := StatsComponent.new()
	stats.base = {"critical_chance":.8,"attack":10}
	stats.set_source("first",[{"stat":"critical_chance","op":"flat","value":.5}])
	stats.set_source("second",[{"stat":"critical_chance","op":"multiply","value":2}])
	check.call(stats.value("critical_chance")==1,"stacked probability bonuses cap at 100 percent")
	check.call(stats.copy_for_preview().value("critical_chance")==1,"equipment preview uses the same probability cap")
	stats.remove_source("second")
	stats.remove_source("first")
	check.call(is_equal_approx(stats.value("critical_chance"),.8),"removing capped bonuses restores original uncapped contributions")
	stats.set_source("zero",[{"stat":"critical_chance","op":"override","value":0}])
	check.call(stats.value("critical_chance")==0,"zero critical override remains zero")
	stats.set_source("zero",[{"stat":"critical_chance","op":"override","value":2}])
	check.call(stats.value("critical_chance")==1,"critical overrides obey probability bounds")
	stats.base.attack = 30
	check.call(stats.value("attack")==30,"probability cap does not limit ordinary combat stats")
	session.hud.close_panel(true)
	session.new_journey()
	session.change_area("area.grove",false)
	freeze(session)
	var trainer: Actor = session.world.trainer
	var target: Actor
	for actor in session.world.actors:
		if actor.faction==Factions.Team.WILD and actor.identity.begins_with("encounter:"):
			target = actor
			break
	if target==null:
		check.call(false,"authored enemy available for build persistence check")
		return
	var target_id := target.identity
	var item: Dictionary = session.world.item_generator.generate("item.charm",1,0)
	item.affixes = [{"id":"test-bounds","name":"Bounds fixture","modifiers":[{"stat":"critical_chance","op":"flat","value":2},{"stat":"status_duration","op":"flat","value":7200}]}]
	check.call(SaveStore.valid_item(item) and ContentValidator.modifiers(item.affixes[0].modifiers,"fixture").is_empty(),"strong build modifiers are valid item data")
	var preview := TooltipPresenter.item_comparison(item,trainer.combat)
	check.call(preview.stats.any(func(row): return row.id=="critical_chance" and row.after==1) and trainer.critical_chance<1,"real equipment comparison caps probability without mutating the wearer")
	session.inventory.add(item)
	session.equip(session.inventory.items.size()-1)
	var expected_rng := RandomNumberGenerator.new()
	expected_rng.state = session.world.damage.rng.state
	expected_rng.randf()
	var hit: Dictionary = session.world.damage.apply(trainer,target,Database.abilities["ability.spark"])
	check.call(session.world.damage.rng.state==expected_rng.state,"guaranteed direct critical still consumes exactly one RNG draw")
	check.call(hit.get("critical",false) and trainer.critical_chance==1,"equipped overcap build produces bounded guaranteed critical hits")
	var entry: Dictionary = target.statuses.entries.get("status.burn",{})
	check.call(not entry.is_empty() and entry.remaining==3600 and entry.source.critical_chance==1,"real ability stores capped duration and source probability")
	target.statuses.tick(.25)
	target.statuses.apply("status.burn",trainer,100)
	check.call(target.statuses.entries["status.burn"].remaining==3600 and target.statuses.entries["status.burn"].stacks==2,"refresh caps total duration without discarding status stacks")
	var expected := TooltipPresenter.t("tip.status")%[TooltipPresenter.t("status.burn"),3600,Database.statuses["status.burn"].max_stacks]
	check.call(expected in TooltipPresenter.ability_text(Database.abilities["ability.spark"],trainer.combat),"ability tooltip shows actual bounded status duration")
	check.call(CombatSaveSchema.valid(target.combat.to_dict()),"combat created by a valid build fits the save schema")
	var path := "user://combat-bounds-check.json"
	var saved := SaveStore.write(session.save_data(),path,SavedJourney.valid)
	check.call(saved,"strong equipped build and its active effects can be saved")
	var loaded: bool = saved and session.load_game(path)
	check.call(loaded,"bounded build journey loads through the real session path")
	freeze(session)
	var restored: Actor
	for actor in session.world.actors:
		if actor.identity==target_id: restored = actor; break
	var ready: bool = loaded and restored!=null and restored.statuses.entries.has("status.burn")
	check.call(ready and restored.statuses.entries["status.burn"].remaining==3600 and session.world.trainer.critical_chance==1,"save/load preserves equipped probability and bounded active duration")
	if ready:
		var values := TooltipPresenter.status_values(restored.statuses.entries["status.burn"],restored.combat)
		var before := restored.health.current
		expected_rng.state = session.world.damage.rng.state
		expected_rng.randf()
		restored.statuses.tick(1)
		check.call(session.world.damage.rng.state==expected_rng.state,"restored guaranteed periodic critical consumes exactly one RNG draw")
		check.call(is_equal_approx(before-restored.health.current,values.critical_damage),"restored periodic damage honors the saved guaranteed-critical source")
		session.unequip_trainer("charm")
		check.call(is_equal_approx(session.world.trainer.critical_chance,Database.rules.stat_defaults.critical_chance) and restored.statuses.entries["status.burn"].source.critical_chance==1,"unequip restores current stats without rewriting an existing effect source")
		restored.statuses.apply("status.burn",session.world.trainer)
		check.call(restored.statuses.entries["status.burn"].remaining==Database.statuses["status.burn"].duration and restored.statuses.entries["status.burn"].source.critical_chance==session.world.trainer.critical_chance,"reapplication uses current equipment after cap removal")
	else:
		for message in ["restored RNG","restored damage","unequip source continuity","reapplication"]: check.call(false,message)
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	session.new_journey()
	session.change_area("area.haven",false)
