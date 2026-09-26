extends RefCounted

func run(session, check: Callable) -> void:
	session.new_journey()
	session.change_area("area.haven",false)
	session.hud.close_panel(true)
	for actor in session.world.actors: actor.set_physics_process(false)
	session.world.set_physics_process(false)
	var creature: CreatureInstance = session.party.roster[0]
	var state := creature.ensure_combat()
	var generator := ItemGenerator.new()
	generator.rng.seed = 883
	session.inventory.items.clear()
	session.inventory.add(generator.generate("item.ember",1,0))
	session.equip(0,0)
	state.health.current = state.health.maximum*.57
	state.energy.current = 23
	var ability: AbilityData = Database.abilities[creature.abilities[1]]
	state.cooldowns.use(ability)
	state.stats.set_source("status:test",[{"stat":"speed","op":"multiply","value":.55}])
	var candidate := generator.generate("item.prism",1,0)
	candidate.affixes = [{"modifiers":[{"stat":"speed","op":"add","value":.2},{"stat":"health","op":"flat","value":35}]}]
	session.inventory.add(candidate)
	var before := JSON.stringify(state.to_dict())
	var held_before := creature.held_item.duplicate(true)
	var inventory_before: Dictionary = session.inventory.to_dict()
	var values := TooltipPresenter.item_comparison(candidate,state,ability)
	check.call(JSON.stringify(state.to_dict())==before and creature.held_item==held_before and session.inventory.to_dict()==inventory_before,"equipment preview leaves health, energy, timers, ownership and inventory unchanged")
	check.call(values.stats.any(func(row): return row.id=="attack" and row.delta<0) and values.after_mods.projectiles==3,"comparison exposes lost attack and added projectile targets together")
	session.equip(0,0)
	check.call(values.stats.all(func(row): return is_equal_approx(state.stats.value(row.id),row.after)),"held item comparison matches actual equip including traits, affixes and current modifiers")
	check.call(state.ability_mods()==values.after_mods and is_equal_approx(TooltipPresenter.ability_values(ability,state).damage,values.after_ability.damage),"ability and projectile preview match the equipped combat pipeline")
	check.call(is_equal_approx(state.health.current/state.health.maximum,.57) and state.energy.current==23 and state.cooldowns.remaining(ability.id)>0,"equipment replacement preserves health ratio, energy and existing recharge")
	var count: int = session.inventory.items.size()
	session.inventory.capacity = count
	check.call(not session.unequip_held(0) and creature.held_item==candidate and session.inventory.items.size()==count,"full inventory cannot destroy or detach a held item")
	session.inventory.capacity = 30
	check.call(session.unequip_held(0) and creature.held_item.is_empty() and session.inventory.items.size()==count+1 and state.ability_mods().projectiles==1,"unequip returns one item and removes its mechanics")
	check.call(is_equal_approx(state.health.current/state.health.maximum,.57) and not session.unequip_held(0),"unequip preserves health ratio and repeated removal cannot duplicate items")
	state.stats.remove_source("status:test")
	var trainer: Actor = session.world.trainer
	trainer.health.current = trainer.health.maximum*.4
	session.inventory.items.clear()
	var charm := generator.generate("item.charm",1,0)
	session.inventory.add(charm)
	var trainer_values := TooltipPresenter.item_comparison(charm,trainer.combat,Database.abilities["ability.pulse"])
	session.equip(0,0)
	check.call(trainer_values.stats.all(func(row): return is_equal_approx(trainer.stats.value(row.id),row.after)) and is_equal_approx(trainer.health.current/trainer.health.maximum,.4),"trainer slot comparison matches actual equip and preserves health")
	session.inventory.capacity = 0
	check.call(not session.unequip_trainer("charm") and session.equipment.has("charm"),"full inventory also protects trainer equipment")
	session.inventory.capacity = 30
	check.call(session.unequip_trainer("charm") and trainer.health.maximum==180 and is_equal_approx(trainer.health.current,72),"trainer unequip removes slot modifiers without healing")
	var source: Actor = session.world.spawn_actor("species.rill",Factions.Team.WILD,Vector2(700,600))
	source.set_physics_process(false)
	source.stats.base.attack = 80
	source.critical_chance = 0
	state.rest()
	state.statuses.apply("status.burn",source)
	state.statuses.apply("status.burn",source)
	var entry: Dictionary = state.statuses.entries["status.burn"]
	var rng_before: int = session.world.damage.rng.state
	var predicted := TooltipPresenter.status_values(entry,state)
	check.call(predicted.stacks==2 and predicted.ticks==4 and predicted.damage>0,"status inspection reports remaining stacks, ticks and resisted damage")
	check.call(session.world.damage.rng.state==rng_before and entry.remaining==4,"status inspection does not advance time or consume combat randomness")
	source.stats.base.attack = 500
	session.world.remove_actor(source)
	await session.get_tree().process_frame
	check.call(is_equal_approx(TooltipPresenter.status_values(entry,state).damage,predicted.damage),"periodic preview uses the retained source snapshot after source removal")
	var health_before := state.health.current
	state.statuses.tick(1)
	check.call(is_equal_approx(health_before-state.health.current,predicted.damage),"displayed periodic damage agrees with an actual damage tick")
	entry.tick = entry.remaining
	check.call(TooltipPresenter.status_values(entry,state).ticks==1,"status inspection includes a tick exactly on the expiry boundary")
	entry.source.critical_chance = 1
	var critical := TooltipPresenter.status_values(entry,state)
	check.call(is_equal_approx(critical.critical_damage,critical.damage*1.5),"status preview includes the actual critical multiplier")
	entry.source.faction = state.faction
	check.call(not TooltipPresenter.status_values(entry,state).damaging,"status inspection respects friendly-source periodic damage suppression")
	entry.source.faction = Factions.Team.WILD
	session.hud.show_statuses(0)
	check.call(session.get_tree().paused and session.hud.panel.visible,"status inspection pauses combat for readable current values")
	var locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	check.call("remaining" in TooltipPresenter.status_text(entry,state) and not "status." in TooltipPresenter.status_text(entry,state),"status inspection resolves English localization keys")
	TranslationServer.set_locale(locale)
	session.hud.close_panel(true)
	session.new_journey()
	session.change_area("area.haven",false)
