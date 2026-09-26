extends RefCounted

const SAVE_PATH := "user://arrival-checks.json"

func freeze(session) -> void:
	session.world.set_physics_process(false)
	for actor in session.world.actors: actor.set_physics_process(false)

func run(session, check: Callable, capture: Callable = Callable()) -> void:
	session.new_journey()
	session.change_area("area.grove",false)
	session.hud.close_panel(true)
	freeze(session)
	var world: GameWorld = session.world
	world.trainer.position = world.navigation.safe_position_near(Vector2(1700,1050))
	world.trainer.last_direction = Vector2.UP
	session.party.mode = ActorBrain.Mode.HOLD
	for slot in session.party.active_actors.size():
		var actor: Actor = session.party.active_actors[slot]
		actor.position = world.navigation.safe_position_near(world.trainer.position+Vector2(-100+slot*180,-70))
		actor.last_direction = Vector2.DOWN if slot==0 else Vector2.LEFT
		actor.brain.mode = ActorBrain.Mode.HOLD
	# A real held-item summon rule makes replaying construction events observable.
	var original: ItemData = Database.items["item.seed"]
	var with_summon: ItemData = original.duplicate(true)
	with_summon.triggers = [{"event":"summon","effect":"shield","amount":30,"cooldown":.3}]
	Database.items["item.seed"] = with_summon
	var generator := ItemGenerator.new()
	var first: Actor = session.party.active_actors[0]
	first.individual.held_item = generator.generate("item.seed",1,0)
	first.apply_equipment()
	first.health.current = first.health.maximum*.5
	first.health.shield = 7
	first.energy.current = 17
	first.triggers.cooldowns.clear()
	first.abilities.cooldowns.use(Database.abilities["ability.flare"])
	var baseline: Dictionary = JSON.parse_string(JSON.stringify(session.save_data()))
	var signals_seen := [0]
	var on_summon := func(_id): signals_seen[0] += 1
	session.party.creature_swapped_in.connect(on_summon)
	check.call(SaveStore.write(baseline,SAVE_PATH,SavedJourney.valid),"arrival snapshot writes active placements under persistent creature IDs")
	check.call(session.load_game(SAVE_PATH),"arrival snapshot loads away from area entry")
	freeze(session)
	var restored: Dictionary = JSON.parse_string(JSON.stringify(session.save_data()))
	check.call(restored.party_state==baseline.party_state and restored.trainer.position==baseline.trainer.position and restored.trainer.direction==baseline.trainer.direction,"load restores trainer and companion positions/facing before a simulation tick")
	check.call(restored.party==baseline.party and signals_seen[0]==0,"load preserves combat state and does not replay summon rewards or swap-in events")
	check.call(session.world.trainer.presentation.character_animation.facing_row==2 and session.party.active_actors[0].presentation.creature_animation.facing=="south" and session.party.active_actors[1].presentation.sprite.flip_h,"initial presentation uses restored directions before rendering")
	check.call(session.party.active_actors.all(func(actor): return actor.spawn_origin==actor.position and actor.presentation.creature_animation.previous_position==actor.position and actor.brain.recovery_count==0),"actor and animation origins start at restored positions without recovery teleports")
	# Repeated load must not farm the summon shield.
	check.call(session.load_game(SAVE_PATH) and session.party.active_actors[0].health.shield==7 and signals_seen[0]==0,"reloading the same file cannot farm summon shields")
	freeze(session)
	for actor in session.party.active_actors: actor.set_physics_process(true)
	for frame in 4: await session.get_tree().physics_frame
	freeze(session)
	check.call(session.party.placements()==baseline.party_state.placements and session.party.active_actors.all(func(actor): return actor.brain.recovery_count==0),"HOLD companions remain at their saved locations after physics resumes")
	if capture.is_valid(): await capture.call("restored-hold")
	session.change_area("area.haven",false)
	freeze(session)
	check.call(signals_seen[0]==2 and session.party.active_actors[0].health.shield>7,"actual area arrival still emits summon events and applies summon equipment")
	# Older v3 saves omitted placement and facing. Spawn near the restored trainer.
	var legacy := baseline.duplicate(true)
	legacy.party_state.erase("placements")
	legacy.trainer.erase("direction")
	check.call(SaveStore.write(legacy,SAVE_PATH,SavedJourney.valid) and session.load_game(SAVE_PATH),"v3 saves without optional placement fields still load")
	freeze(session)
	check.call(session.party.active_actors.all(func(actor): return actor.position.distance_to(session.world.trainer.position)<150 and session.world.navigation.point_clear(actor.position,actor.body_radius)),"legacy HOLD companions spawn on clear ground near the saved trainer, not the entrance")
	if capture.is_valid(): await capture.call("legacy-near-trainer")
	var blocked := baseline.duplicate(true)
	var first_id: String = baseline.party[baseline.active[0]].id
	var obstacle: Rect2 = Database.areas["area.grove"].layout.obstacles()[0]
	blocked.party_state.placements[first_id].position = [obstacle.get_center().x,obstacle.get_center().y]
	check.call(SaveStore.write(blocked,SAVE_PATH,SavedJourney.valid) and session.load_game(SAVE_PATH),"load accepts an old placement whose geometry has since changed")
	freeze(session)
	check.call(session.party.active_actors.all(func(actor): return session.world.navigation.point_clear(actor.position,actor.body_radius)),"blocked saved companion positions resolve to clear ground before spawning")
	var downed := baseline.duplicate(true)
	downed.party[0].health_ratio = 0
	downed.party[0].combat.health_ratio = 0
	check.call(SaveStore.write(downed,SAVE_PATH,SavedJourney.valid) and session.load_game(SAVE_PATH),"downed companion arrival loads")
	freeze(session)
	check.call(session.party.active_actors[0].health.current==0 and session.party.placements()==baseline.party_state.placements,"downed companion keeps identity, position and zero health without a summon reward")
	if capture.is_valid(): await capture.call("downed")
	for mutation in [null,[],{"position":[NAN,0],"direction":[1,0]},{"position":[1],"direction":[1,0]},{"position":[1,2],"direction":[0,0]},{"position":[1,2],"direction":[2,0]},{"position":[1,2],"direction":[INF,0]}]:
		var invalid := baseline.duplicate(true)
		invalid.party_state.placements[first_id] = mutation
		check.call(not SaveStore.validate_shape(invalid),"malformed arrival pose rejected before runtime: "+str(mutation))
	for id in ["missing-creature",str(baseline.party[2].id)]:
		var invalid := baseline.duplicate(true)
		invalid.party_state.placements = {id:baseline.party_state.placements[first_id]}
		check.call(not SavedJourney.valid(invalid),"placement must belong to an active creature: "+id)
	var invalid_trainer := baseline.duplicate(true)
	invalid_trainer.trainer.direction = [0,0]
	check.call(not SaveStore.validate_shape(invalid_trainer),"zero trainer facing is rejected")
	session.party.creature_swapped_in.disconnect(on_summon)
	Database.items["item.seed"] = original
	session.new_journey()
	session.change_area("area.haven",false)
	freeze(session)
