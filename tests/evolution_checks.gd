extends RefCounted

func run(session, check: Callable) -> void:
	session.new_journey()
	session.change_area("area.haven",false)
	session.hud.close_panel()
	var world: GameWorld = session.world
	world.set_physics_process(false)
	for entry in world.actors: entry.set_physics_process(false)
	var party: PartySystem = session.party
	var creature := party.roster[0]
	var actor: Actor = party.active_actors[0]
	var companion: Actor = party.active_actors[1]
	var identity := creature.persistent_id
	check.call(not party.evolve(-1) and not party.evolve(party.roster.size()) and not party.evolve(0),"evolution rejects invalid roster indices and insufficient level")
	creature.level = 5
	creature.refresh_stats()
	Progression.select_command(creature,"ability.breath")
	var target := world.spawn_actor("species.briar",Factions.Team.WILD,actor.position+Vector2.DOWN*100)
	target.set_physics_process(false)
	actor.combat.rest()
	actor.health.current = actor.health.maximum*.37
	actor.health.shield = 19
	actor.health.invulnerable = .15
	actor.energy.current = 46
	actor.statuses.apply("status.wet",target)
	actor.abilities.cooldowns.use(Database.abilities["ability.flare"])
	actor.abilities.cooldowns.tick(.2)
	check.call(actor.abilities.cast("ability.spark",target),"evolution fixture begins a real cast")
	actor.presentation.creature_animation.tick(0)
	var state := actor.combat
	var before := state.to_dict()
	var positions := [world.trainer.position,actor.position,companion.position,target.position]
	var phase := actor.abilities.phase
	var remaining := actor.abilities.remaining
	var health_connections := actor.health.changed.get_connections().size()
	session.hud.show_party()
	var buttons: Array = session.hud.panel.find_children("","Button",true,false).filter(func(button): return button.text=="Эволюция")
	check.call(buttons.size()==1,"party exposes the eligible evolution action")
	if buttons.size()==1: buttons[0].pressed.emit()
	check.call(creature.species_id=="species.solstice" and creature.persistent_id==identity and party.active_actors[0]==actor and session.world==world,"UI evolution retains world, actor and creature identity")
	check.call(positions==[world.trainer.position,actor.position,companion.position,target.position],"evolution does not relocate trainer, companions or enemies")
	check.call(actor.combat==state and is_equal_approx(actor.health.current/actor.health.maximum,.37) and actor.health.shield==19 and actor.health.invulnerable==.15 and actor.energy.current==46,"evolution preserves health ratio, shield, invulnerability and energy")
	var after := state.to_dict()
	for key in ["statuses","cooldowns","triggers"]:
		check.call(before.get(key)==after.get(key),"evolution preserves persistent "+key)
	check.call(actor.abilities.phase==phase and actor.abilities.remaining==remaining and actor.abilities.target_ref!=null and actor.abilities.target_ref.get_ref()==target,"evolution preserves an ongoing cast and target")
	check.call(actor.species.id==&"species.solstice" and actor.ability_id(1)=="ability.breath" and actor.ability_mods().get("projectiles")==2,"evolution updates actor definition and passive while retaining chosen command")
	var animation := actor.presentation.creature_animation
	check.call(animation.definition.id==&"animation.solstice" and animation.definition.texture!=Database.animations["animation.cinder"].texture and animation.current_clip=="windup" and animation.facing=="south","evolved creature uses its own art and retains planted cast facing")
	check.call(actor.health.changed.get_connections().size()==health_connections,"presentation refresh does not duplicate health subscriptions")
	var portraits: Array = session.hud.panel.find_children("","TextureRect",true,false)
	check.call(portraits.any(func(view): return view.texture==actor.species.portrait) and actor.species.portrait!=null,"party portrait changes to the evolved silhouette")
	check.call(not party.evolve(0),"evolution cannot be repeated to reset state")
	var restored := CreatureInstance.from_dict(creature.to_dict())
	check.call(restored.species_id=="species.solstice" and restored.persistent_id==identity and restored.ensure_combat().health.shield==19,"evolved identity and live state survive serialization")
	session.hud.close_panel()
	# Reserve and defeated actors must follow the same data path without revival.
	var rng := RandomNumberGenerator.new()
	rng.seed = 178
	var reserve := CreatureInstance.create(Database.species["species.cinder"],rng)
	reserve.level = 5
	party.add(reserve)
	check.call(party.evolve(3) and reserve.species_id=="species.solstice","reserve evolution does not require an actor")
	party.swap_remaining = 0
	check.call(party.swap(3,1) and party.active_actors[1].presentation.creature_animation.definition.id==&"animation.solstice","summoning an evolved reserve uses its own animation")
	party.active_actors[1].set_physics_process(false)
	var fallen := CreatureInstance.create(Database.species["species.cinder"],rng)
	fallen.level = 5
	party.add(fallen)
	party.swap_remaining = 0
	party.swap(4,1)
	var dead: Actor = party.active_actors[1]
	dead.set_physics_process(false)
	dead.health.invulnerable = 0
	dead.health.damage(100000)
	dead.presentation.creature_animation.tick(1)
	var evolved_dead := party.evolve(4)
	var fall := dead.presentation.creature_animation
	var final_frame: int = fall.definition.clips[fall.definition.clip_id("death",fall.facing)][-1]
	check.call(evolved_dead and dead.health.current==0 and fall.current_clip=="death" and fall.dead_time==fall.definition.death_duration and fall.current_frame==final_frame,"evolving a defeated creature preserves its completed fall without revival")
	var falling := CreatureInstance.create(Database.species["species.cinder"],rng)
	falling.level = 5
	party.add(falling)
	party.swap_remaining = 0
	party.swap(5,1)
	var mid_fall: Actor = party.active_actors[1]
	mid_fall.set_physics_process(false)
	mid_fall.health.invulnerable = 0
	mid_fall.health.damage(100000)
	mid_fall.presentation.tick(.2)
	var old_fall := mid_fall.presentation.creature_animation
	var progress := old_fall.dead_time/old_fall.definition.death_duration
	var evolved_mid_fall := party.evolve(5)
	var new_fall := mid_fall.presentation.creature_animation
	check.call(evolved_mid_fall and mid_fall.health.current==0 and new_fall.current_clip=="death" and is_equal_approx(new_fall.dead_time/new_fall.definition.death_duration,progress),"evolution preserves fractional fall progress across different clip durations")
	world.remove_actor(target)
