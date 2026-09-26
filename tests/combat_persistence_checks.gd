extends RefCounted

func freeze_world(session) -> void:
	session.world.set_physics_process(false)
	for actor in session.world.actors: actor.set_physics_process(false)

func run(session, check: Callable) -> void:
	session.new_journey()
	session.change_area("area.grove",false)
	freeze_world(session)
	var party: PartySystem = session.party
	var individual := party.roster[0]
	var actor: Actor = party.active_actors[0]
	var state := actor.combat
	var source: Actor = session.world.actors.filter(func(entry): return entry.faction==Factions.Team.WILD)[0]
	source.critical_chance = 0
	source.stats.base["attack"] = 10
	actor.abilities.cooldowns.use(Database.abilities["ability.flare"])
	actor.energy.current = 12
	actor.health.shield = 7
	actor.statuses.apply("status.burn",source)
	actor.statuses.apply("status.slow",source)
	var cooldown := actor.abilities.cooldowns.remaining("ability.flare")
	check.call(party.swap(2,0),"persistent-state test recalls a living companion")
	party.active_actors[0].set_physics_process(false)
	check.call(individual.combat==state and state.energy.current==12 and state.health.shield==7 and state.cooldowns.remaining("ability.flare")==cooldown,"recall preserves the individual's energy, shield and cooldown object")
	check.call(state.statuses.entries.size()==2 and state.actor_ref==null,"recall preserves effects and detaches temporary scene representation")
	session.world.remove_actor(source)
	await session.get_tree().physics_frame
	await session.get_tree().physics_frame
	state.health.shield = 0
	var health_before := state.health.current
	party.tick(1.1)
	check.call(not is_instance_valid(source) and state.health.current<health_before,"burn still deals damage in reserve after its source node is freed")
	check.call(is_equal_approx(state.energy.current,26.3) and is_equal_approx(state.cooldowns.remaining("ability.flare"),maxf(0,cooldown-1.1)),"reserve ticks energy regeneration and cooldown exactly once")
	check.call(is_equal_approx(individual.health_ratio,state.health.current/state.health.maximum),"reserve damage updates roster health")
	party.swap_remaining = 0
	check.call(not party.swap(0,-1),"negative active slot is rejected")
	var remaining_before := state.cooldowns.remaining("ability.flare")
	check.call(party.swap(0,0) and party.active_actors[0].combat==state and is_equal_approx(state.cooldowns.remaining("ability.flare"),remaining_before),"resummon reuses combat state without refreshing cooldown")
	freeze_world(session)
	var trainer: Actor = session.world.trainer
	trainer.health.current = 72
	trainer.health.shield = 9
	trainer.energy.current = 23
	trainer.dodge_cooldown = .65
	trainer.abilities.cooldowns.use(Database.abilities["ability.pulse"])
	var trainer_state := trainer.combat
	var enemy: Actor = session.world.actors.filter(func(entry): return entry.faction==Factions.Team.WILD)[0]
	var enemy_id := enemy.identity
	enemy.statuses.apply("status.burn",trainer)
	enemy.energy.current = 17
	enemy.abilities.cooldowns.use(Database.abilities["ability.flare"])
	var enemy_snapshot := enemy.combat.to_dict()
	var boss: Actor = session.world.actors.filter(func(entry): return entry.faction==Factions.Team.BOSS)[0]
	boss.brain.boss_phase = 2
	boss.brain.boss_time = .7
	party.mode = ActorBrain.Mode.DEFENSIVE
	party.swap_remaining = 2.4
	session.change_area("area.haven",false)
	freeze_world(session)
	check.call(session.world.trainer.combat==trainer_state and trainer_state.health.current==72 and trainer_state.energy.current==23 and trainer_state.health.shield==9 and trainer_state.dodge_cooldown==.65,"area travel preserves trainer health, energy, shield and dodge cooldown")
	check.call(party.active_actors[0].combat==state and state.statuses.entries.size()==2,"area travel keeps companion effects and state identity")
	session.change_area("area.grove",false)
	freeze_world(session)
	enemy = session.world.actors.filter(func(entry): return entry.identity==enemy_id)[0]
	check.call(enemy.combat.to_dict()==enemy_snapshot,"enemy cooldowns, statuses and energy survive leaving and revisiting an area")
	boss = session.world.actors.filter(func(entry): return entry.faction==Factions.Team.BOSS)[0]
	check.call(boss.brain.boss_phase==2 and is_equal_approx(boss.brain.boss_time,.7),"boss phase and special-attack timer survive travel")
	state.triggers.cooldowns["test-trigger"] = 1.7
	var saved_state := state.to_dict()
	var payload: Dictionary = session.save_data()
	check.call(SaveStore.write(payload,"user://test-combat.json"),"v3 complete combat save writes")
	trainer_state.rest()
	state.rest()
	check.call(session.load_game("user://test-combat.json"),"v3 complete combat save loads")
	freeze_world(session)
	party = session.party
	state = party.roster[0].combat
	check.call(is_equal_approx(state.energy.current,saved_state.energy) and is_equal_approx(state.cooldowns.remaining("ability.flare"),remaining_before) and state.statuses.entries.size()==2 and is_equal_approx(state.triggers.cooldowns["test-trigger"],1.7),"JSON roundtrip restores energy, cooldowns, effects and trigger timers")
	check.call(is_equal_approx(party.swap_remaining,2.4) and party.mode==ActorBrain.Mode.DEFENSIVE,"save restores party command mode and switching lockout")
	check.call(session.world.trainer.health.current==72 and session.world.trainer.energy.current==23 and is_equal_approx(session.world.trainer.dodge_cooldown,.65),"save restores trainer combat state")
	var statuses_before := state.statuses.to_array()
	session.world.set_physics_process(true)
	for entry in session.world.actors: entry.set_physics_process(true)
	session.hud.show_inventory()
	await session.get_tree().physics_frame
	await session.get_tree().physics_frame
	check.call(state.statuses.to_array()==statuses_before,"menu pause does not consume status time")
	session.hud.close_panel()
	freeze_world(session)
	party.swap_remaining = 0
	party.swap(2,0)
	freeze_world(session)
	state.health.current = .01
	state.health.shield = 0
	state.health.invulnerable = 0
	party.tick(1.1)
	party.swap_remaining = 0
	check.call(state.health.current==0 and party.roster[0].health_ratio==0 and not party.swap(0,0),"periodic damage can down a reserve creature and prevents summoning it")
	party.rest()
	check.call(state.health.current==state.health.maximum and state.statuses.entries.is_empty() and state.cooldowns.timers.is_empty() and state.energy.current==state.energy.maximum,"explicit rest revives reserve and clears its combat timers")
	state.health.current *= .5
	state.energy.current = 14
	state.cooldowns.use(Database.abilities["ability.flare"])
	var old_maximum := state.health.maximum
	Progression.award(party.roster[0],Progression.threshold(party.roster[0].level))
	check.call(state.stats.level==party.roster[0].level and state.health.maximum>old_maximum and is_equal_approx(state.health.current/state.health.maximum,.5),"reserve level-up refreshes retained stats while preserving health ratio")
	party.roster[0].level = 5
	var evolved_base: Dictionary = Database.species["species.solstice"].base_stats.duplicate()
	evolved_base.merge(Database.rules.stat_defaults)
	check.call(Progression.evolve(party.roster[0]) and state.stats.base==evolved_base and state.energy.current==14 and state.cooldowns.remaining("ability.flare")>0,"evolution updates persistent stats without clearing energy or cooldowns")
	verify_timing(session.world.trainer,check)
	verify_invalid_saves(payload,check)
	var dead_save: Dictionary = session.save_data()
	dead_save.trainer.combat.health_ratio = 0
	dead_save.trainer.health = 0
	SaveStore.write(dead_save,"user://test-dead-combat.json")
	check.call(session.load_game("user://test-dead-combat.json") and session.world.trainer.health.current==0 and session.get_tree().paused,"loading a defeated trainer keeps defeat state rather than granting free health")
	session.revive()
	check.call(session.world.trainer.health.current==session.world.trainer.health.maximum and session.world.trainer.statuses.entries.is_empty(),"explicit defeat recovery resets retained trainer state")

func verify_timing(source: Actor, check: Callable) -> void:
	source.critical_chance = 0
	var large := CombatState.new()
	var small := CombatState.new()
	for state in [large,small]:
		state.configure(Database.species["species.briar"],Factions.Team.WILD)
		state.health.reset(1000)
		state.damage_system = DamageSystem.new()
		state.damage_system.rules = Database.rules
		state.statuses.apply("status.burn",source)
	large.tick(10)
	for index in 40: small.tick(.25)
	check.call(is_equal_approx(large.health.current,small.health.current) and large.health.current<1000 and large.statuses.entries.is_empty(),"periodic damage catches up all valid ticks without ticking beyond expiry")
	var charges := CooldownComponent.new()
	var ability := AbilityData.new()
	ability.id = "test.charges"
	ability.charges = 3
	ability.cooldown = 1
	for index in 3: charges.use(ability)
	charges.tick(3.1)
	check.call(charges.charges[ability.id]==3 and charges.timers.is_empty(),"one long update recovers all elapsed ability charges")

func verify_invalid_saves(payload: Dictionary, check: Callable) -> void:
	var invalid := payload.duplicate(true)
	invalid.save_version = 3
	invalid.party[0].combat.statuses = [{"id":"status.burn","source":{"attack":"oops"}}]
	check.call(SaveStore.migrate(invalid).is_empty(),"malformed periodic source rejected before runtime restore")
	invalid = payload.duplicate(true)
	invalid.party[0].combat.cooldowns = {"timers":{"ability.flare":{"remaining":2,"base":0}}}
	check.call(SaveStore.migrate(invalid).is_empty(),"zero recharge interval rejected")
	invalid = payload.duplicate(true)
	invalid.trainer.combat.energy = NAN
	check.call(SaveStore.migrate(invalid).is_empty(),"nonfinite battle values rejected")
	invalid = payload.duplicate(true)
	invalid.trainer.position = [INF,10]
	check.call(SaveStore.migrate(invalid).is_empty(),"nonfinite world coordinates rejected")
	invalid = payload.duplicate(true)
	invalid.active = [.5]
	check.call(SaveStore.migrate(invalid).is_empty(),"fractional party indices rejected")
	var legacy := {"save_version":2,"party":[{"id":"old","species":"species.cinder","health_ratio":.41}],"inventory":{}}
	var migrated := SaveStore.migrate(legacy)
	var creature := CreatureInstance.from_dict(migrated.party[0])
	check.call(migrated.save_version==3 and is_equal_approx(creature.ensure_combat().health.current/creature.combat.health.maximum,.41),"v2 migration preserves legacy creature health")
