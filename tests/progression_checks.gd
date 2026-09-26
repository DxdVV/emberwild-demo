extends RefCounted

func run(session, check: Callable) -> void:
	session.new_journey()
	session.change_area("area.haven",false)
	session.hud.close_panel()
	var world: GameWorld = session.world
	world.set_physics_process(false)
	for actor in world.actors: actor.set_physics_process(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 910
	var creature := CreatureInstance.create(Database.species["species.cinder"],rng)
	creature.traits = ["enduring"]
	check.call(not Progression.select_command(creature,"ability.breath"),"locked command cannot be selected")
	Progression.award(creature,Progression.threshold(1)+Progression.threshold(2))
	check.call(creature.level==3 and Progression.select_command(creature,"ability.breath"),"level three unlocks a selectable tactical command")
	var source := world.spawn_actor(creature.species_id,Factions.Team.COMPANION,Vector2(750,700),creature)
	source.set_physics_process(false)
	source.critical_chance = 0
	var front := target(world,Vector2(850,700))
	var rear := target(world,Vector2(650,700))
	var side := target(world,Vector2(750,800))
	var ally := world.spawn_actor("species.briar",Factions.Team.COMPANION,Vector2(850,710))
	ally.set_physics_process(false)
	var front_health := front.health.current
	check.call(source.ability_id(1)=="ability.breath" and source.abilities.cast(source.ability_id(1),front),"actor casts its individual command loadout")
	check.call(front.health.current==front_health,"cone waits for its actual windup before dealing damage")
	source.abilities.tick(.4)
	check.call(front.health.current<front_health and rear.health.current==rear.health.maximum and side.health.current==side.health.maximum and ally.health.current==ally.health.maximum,"cone hits only enemies inside the forward sector")
	check.call(is_equal_approx(front.statuses.entries["status.burn"].remaining,5),"enduring trait extends applied status through stats")
	check.call(is_equal_approx(source.energy.current,76),"burn-fed passive restores energy after a qualifying hit")
	var command_timer := source.abilities.cooldowns.remaining("ability.breath")
	Progression.select_command(creature,"ability.flare")
	Progression.select_command(creature,"ability.breath")
	check.call(source.abilities.cooldowns.remaining("ability.breath")==command_timer,"changing command cannot reset an existing cooldown")
	var restored := CreatureInstance.from_dict(JSON.parse_string(JSON.stringify(creature.to_dict())))
	check.call(restored.abilities==creature.abilities and restored.ensure_combat().cooldowns.remaining("ability.breath")==command_timer,"JSON save preserves selected command and its recharge")
	var malformed := creature.to_dict()
	malformed.abilities = ["ability.pulse","ability.missing"]
	var normalized := CreatureInstance.from_dict(malformed)
	check.call(normalized.abilities==Database.species[creature.species_id].abilities,"obsolete loadout safely restores valid species slots")
	creature.level = 5
	check.call(Progression.evolve(creature) and creature.abilities[1]=="ability.breath" and source.combat.ability_mods().projectiles==2,"evolution preserves learned command and grants its authored passive")
	creature.traits = ["resonant"]
	creature.refresh_stats()
	creature.held_item = {"base":"item.prism"}
	source.apply_equipment()
	check.call(source.ability_mods()=={"projectiles":4,"chains":1} and source.triggers.rules.any(func(rule): return rule._key.begins_with("trait:passive.ember")),"held item combines with both individual and species passives")
	check.call(is_equal_approx(source.stats.value("attack"),29*(1+4*.14)*.9),"resonance has its data-driven attack tradeoff")
	creature.held_item.clear()
	source.apply_equipment()
	check.call(source.ability_mods()=={"projectiles":2,"chains":1},"removing an item leaves inherited ability modifiers intact")
	creature.traits = ["steadfast"]
	creature.refresh_stats()
	source.health.shield = 0
	source.triggers.fire("swap")
	source.triggers.fire("swap")
	check.call(source.health.shield==14,"steadfast grants one shield within its cooldown")
	var saved := source.combat.to_dict()
	source.combat.restore(saved)
	source.triggers.fire("swap")
	check.call(source.health.shield==14,"restoring combat state does not reset trait trigger cooldown")
	var rule: Dictionary = Database.traits["steadfast"].triggers[0]
	source.triggers.cooldowns.clear()
	source.triggers.cooldowns[JSON.stringify(rule)] = 5.0
	source.triggers.fire("swap")
	check.call(source.health.shield==14,"legacy unprefixed trigger cooldown is honored")
	creature.traits = ["swift"]
	creature.refresh_stats()
	var ability: AbilityData = Database.abilities["ability.breath"]
	var values := TooltipPresenter.ability_values(ability,source.combat)
	source.abilities.cooldowns.reset()
	source.abilities.cooldowns.use(ability,source.stats.value("cooldown_reduction"))
	check.call(is_equal_approx(source.stats.value("speed"),145*1.1) and is_equal_approx(values.cooldown,source.abilities.cooldowns.remaining(ability.id)),"agility changes movement and real recharge shown by tooltip")
	check.call(is_equal_approx(values.damage,source.stats.value("attack")*ability.power),"tooltip damage uses the shared damage calculation")
	verify_passives(world,source,front,check)
	verify_shapes(world,source,front,rear,side,ally,check)
	var invalid_rules: Array = [{"event":"hit","effect":"energy","amount":5,"conditions":{"target_status":"status.missing"}}]
	check.call(not ContentValidator.triggers(invalid_rules,"test",Database).is_empty(),"content validation rejects unknown condition references")
	var previous_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	check.call("Cooldown reduction" in TooltipPresenter.trait_text(Database.traits["swift"]) and "critical hit" in TooltipPresenter.item_text({"base":"item.relic"}),"trait and item mechanics translate from the same authored data")
	TranslationServer.set_locale(previous_locale)
	session.party.roster[0].level = 3
	session.party.roster[0].refresh_stats()
	session.hud.show_party()
	check.call(session.hud.panel.find_children("","OptionButton",true,false).size()==session.party.roster.size(),"each party member exposes its command selector")
	var selector: OptionButton = session.hud.panel.find_children("","OptionButton",true,false)[0]
	selector.item_selected.emit(1)
	check.call(session.party.roster[0].abilities[1]=="ability.breath" and session.get_tree().paused and session.hud.party_expanded_id==session.party.roster[0].persistent_id,"party selector changes the correct member while preserving pause and details")
	var provider: Callable = session.hud.skill_labels[0].get_meta(ContextTooltip.PROVIDER)
	check.call(provider.call()==TooltipPresenter.t(Database.abilities["ability.breath"].name_key)+"\n"+TooltipPresenter.ability_text(Database.abilities["ability.breath"],session.party.active_actors[0].combat),"HUD hover describes the selected command with the same calculated presenter")
	session.hud.close_panel()
	for actor in [source,front,rear,side,ally]: world.remove_actor(actor)

func target(world: GameWorld, at: Vector2) -> Actor:
	var actor := world.spawn_actor("species.briar",Factions.Team.WILD,at)
	actor.set_physics_process(false)
	actor.critical_chance = 0
	return actor

func verify_passives(world: GameWorld, source: Actor, victim: Actor, check: Callable) -> void:
	source.triggers.cooldowns.clear()
	source.energy.current = 20
	victim.statuses.clear()
	source.triggers.fire("hit",{"target":victim})
	check.call(source.energy.current==20,"conditional passive does not fire without its required status")
	victim.statuses.apply("status.burn",source)
	source.triggers.fire("hit",{"target":victim})
	check.call(source.energy.current==26,"conditional passive fires when required status is present")
	victim.health.current = victim.health.maximum*.6
	victim.triggers.fire("damage_taken",{"target":source})
	check.call(victim.health.shield==0,"bark passive waits for its low-health threshold")
	victim.health.current = victim.health.maximum*.4
	victim.triggers.fire("damage_taken",{"target":source})
	check.call(victim.health.shield==18,"bark passive shields below half health")
	var rill := world.spawn_actor("species.rill",Factions.Team.COMPANION,Vector2(800,640))
	rill.set_physics_process(false)
	rill.health.current = 50
	rill.abilities.cast("ability.splash",victim)
	check.call(is_equal_approx(rill.health.current,56),"living-water passive heals on a real ability cast")
	var volt := world.spawn_actor("species.volt",Factions.Team.COMPANION,Vector2(810,650))
	volt.set_physics_process(false)
	volt.critical_chance = 1
	volt.energy.current = 10
	victim.combat.rest()
	world.damage.apply(volt,victim,Database.abilities["ability.arc"])
	check.call(volt.energy.current==18,"recharge passive restores energy from an actual critical hit")
	world.remove_actor(rill)
	world.remove_actor(volt)

func verify_shapes(world: GameWorld, source: Actor, front: Actor, rear: Actor, side: Actor, ally: Actor, check: Callable) -> void:
	source.combat.apply_traits([],[])
	source.critical_chance = 0
	source.stats.base.attack = 10
	for actor in [front,rear,side,ally]: actor.combat.rest()
	world.launch(source,front,Database.abilities["ability.frost"])
	check.call([front,rear,side].all(func(actor): return actor.health.current<actor.health.maximum and actor.statuses.entries.has("status.slow")) and ally.health.current==ally.health.maximum,"nova damages and slows surrounding enemies with no friendly fire")
	for actor in [front,rear,side]: actor.combat.rest()
	front.statuses.apply("status.burn",source)
	AbilityResolver.resolve(world,source,[front,side],Database.abilities["ability.thorn"],{})
	var reacted := front.health.maximum-front.health.current
	var ordinary := side.health.maximum-side.health.current
	check.call(is_equal_approx(reacted,ordinary*1.4),"area reaction bonus applies only to the victim with the required status")
	for actor in [front,rear,side]: actor.combat.rest()
	world.launch(source,front,Database.abilities["ability.sweep"])
	check.call(front.external_velocity.x>200 and front.statuses.entries.has("status.root"),"branch sweep applies both root and a lasting knockback impulse")
	var before := front.position
	front._physics_process(.05)
	check.call(front.position.x>before.x and front.external_velocity.x>0 and front.external_velocity.x<220,"knockback survives AI steering and decays after actual movement")
	for actor in [front,rear,side]: actor.combat.rest()
	world.launch(source,front,Database.abilities["ability.discharge"])
	check.call([front,rear,side].all(func(actor): return actor.statuses.entries.has("status.shock")),"thunder ring applies its authored effect around the caster")
