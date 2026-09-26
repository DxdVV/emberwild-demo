extends Node

const CENTER := Vector2(1190,1000)
const CASES := [{"id":"static20","enemies":20,"moving":false,"loot":0},{"id":"static30","enemies":30,"moving":false,"loot":0},{"id":"moving30","enemies":30,"moving":true,"loot":120},{"id":"obstructed30","enemies":30,"moving":true,"loot":120,"obstructed":true}]
var session
var cases: Array = CASES.duplicate(true)
var scenario: int = -1
var simulation_ticks: int = 0
var duration: float = 20
var warmup: float = 3
var sample_started: bool = false
var transitioning: bool = true
var metrics := FrameMetrics.new()
var reports: Array[Dictionary] = []
var enemies: Array[Actor] = []
var peak_nodes: int = 0
var peak_particles: int = 0
var peak_projectiles: int = 0
var draw_calls: Array[float] = []
var started_events: int = 0
var navigation_searches: int = 0
var output: String = "performance-duration"
var headless: bool = false
var fixture_valid: bool = true
var starting_position := Vector2.ZERO
var movement_distance: float = 0
var source_hashes: Dictionary = {}
var trainer_route := PackedVector2Array()
var trainer_goal := Vector2.INF
var base_nodes: int = 0
var base_orphans: int = 0
var base_node_snapshot: Dictionary = {}
var base_audio_voices: int = 0
var population_samples: Array[Dictionary] = []
var clear_bodies: bool = true
var wall_crossings: int = 0
var previous_wall_side: int = 0

func _ready() -> void:
	headless = DisplayServer.get_name()=="headless"
	for path in ["tests/stress.gd","debug/frame_metrics.gd","scripts/world/game_world.gd","scripts/presentation/loot_marker_batch.gd","scripts/ui/world_labels.gd","scripts/ui/hud.gd","scripts/actors/actor.gd","scripts/actors/brain.gd","scripts/systems/navigation.gd","scripts/presentation/combat_markers.gd","scripts/presentation/actor_presentation.gd","scripts/presentation/effects.gd","shaders/forest_floor.gdshader","resources/layouts/grove.tres"]:
		source_hashes[path] = FileAccess.get_sha256("res://"+path)
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--stress-seconds="): duration = clampf(float(arg.get_slice("=",1)),1,120)
		if arg.begins_with("--stress-case="): cases = CASES.filter(func(entry): return entry.id==arg.get_slice("=",1))
		if arg.begins_with("--stress-output="):
			var candidate := arg.get_slice("=",1)
			if candidate.replace("-","_").is_valid_identifier(): output = candidate
	if cases.is_empty():
		push_error("Unknown stress case")
		get_tree().quit(1)
		return
	CombatProfiler.enabled = "--profile-combat" in args
	# Retained cap allows comparison to prior samples; --stress-uncapped exercises
	# the application's default max_fps=0. Both record VSync and screen refresh.
	Engine.max_fps = 0 if headless or "--stress-uncapped" in args else 60
	session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	session.hud.close_panel()
	session.autosave_remaining = 100000
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	RenderingServer.viewport_set_measure_render_time(session.world_viewport.get_viewport_rid(),true)
	next_scenario.call_deferred()

func next_scenario() -> void:
	transitioning = true
	scenario += 1
	if scenario>=cases.size():
		var file := FileAccess.open("res://build/"+output+".json",FileAccess.WRITE)
		file.store_string(JSON.stringify({"format":2,"cases":reports,"fixture_valid":fixture_valid},"\t"))
		file.close()
		print("DURATION STRESS COMPLETE fixture_valid=",fixture_valid," output=",output)
		Audio.shutdown()
		await get_tree().process_frame
		await get_tree().process_frame
		get_tree().quit(0 if fixture_valid else 1)
		return
	session.new_journey()
	session.change_area("area.grove",false)
	session.hud.close_panel()
	var world: GameWorld = session.world
	for actor in world.actors.duplicate():
		if actor.faction>=Factions.Team.WILD: world.remove_actor(actor)
	await get_tree().process_frame
	if cases[scenario].get("obstructed",false):
		var barrier := Rect2(CENTER+Vector2(-20,-105),Vector2(40,210))
		var obstacles := world.navigation.obstacles.duplicate()
		obstacles.append(barrier)
		world.navigation.configure(world.area.size,obstacles)
		world.navigation.grid_for(14)
		world.navigation.grid_for(32)
		var body := StaticBody2D.new()
		body.position = barrier.get_center()
		body.collision_layer = 1
		var collision := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = barrier.size
		collision.shape = rectangle
		body.add_child(collision)
		var visual := Polygon2D.new()
		visual.polygon = PackedVector2Array([-barrier.size*.5,Vector2(barrier.size.x,-barrier.size.y)*.5,barrier.size*.5,Vector2(-barrier.size.x,barrier.size.y)*.5])
		visual.color = Color("536056")
		body.add_child(visual)
		world.add_child(body)
	world.trainer.position = CENTER+Vector2(-120,0) if cases[scenario].get("obstructed",false) else CENTER
	world.trainer.set_physics_process(false)
	world.trainer.presentation.character_animation.previous_position = world.trainer.position
	world.camera.snap(CENTER)
	for index in session.party.active_actors.size():
		var companion: Actor = session.party.active_actors[index]
		companion.position = world.navigation.safe_position_near(world.trainer.position+Vector2(-45+90*index,50))
		companion.presentation.creature_animation.previous_position = companion.position
	for actor in world.actors: sustain(actor)
	enemies.clear()
	var species := ["species.cinder","species.rill","species.briar","species.volt"]
	for index in int(cases[scenario].enemies):
		var at := world.navigation.safe_position_near(CENTER+Vector2.from_angle(index*TAU/int(cases[scenario].enemies))*210)
		var actor := world.spawn_actor(species[index%species.size()],Factions.Team.WILD,at)
		actor.identity = "stress-enemy-"+str(index)
		sustain(actor)
		enemies.append(actor)
	world.drops.clear()
	for index in int(cases[scenario].loot):
		var at := CENTER+Vector2((index%15)*35-245,(index/15)*30-105)
		world.drops.append({"at":at,"item":world.item_generator.generate("item.ember",3,index%4)})
	world.refresh_labels()
	var args := OS.get_cmdline_user_args()
	world.effects.visible = "--hide-effects" not in args
	session.hud.root.visible = "--hide-ui" not in args
	for actor in world.actors: actor.presentation.visible = "--hide-actors" not in args
	trainer_route.clear()
	trainer_goal = Vector2.INF
	population_samples.clear()
	clear_bodies = true
	wall_crossings = 0
	previous_wall_side = -1
	base_nodes = get_tree().get_node_count()
	base_orphans = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	base_node_snapshot = node_snapshot(get_tree().root)
	base_audio_voices = Audio.spatial_voices.size()
	simulation_ticks = 0
	sample_started = false
	peak_nodes = 0
	peak_particles = 0
	peak_projectiles = 0
	movement_distance = 0
	draw_calls.clear()
	transitioning = false
	print("DURATION STRESS BEGIN ",cases[scenario].id," warmup=",warmup," sampled_simulation_seconds=",duration)

func sustain(actor: Actor) -> void:
	# Damage, statuses and triggers still run; large health keeps population constant.
	actor.health.maximum = 1000000
	actor.health.current = 1000000
	actor.health.immortal = false

func _physics_process(delta: float) -> void:
	if transitioning: return
	simulation_ticks += 1
	var world: GameWorld = session.world
	var trainer := world.trainer
	trainer.combat.tick(delta)
	trainer.abilities.tick(delta)
	trainer.velocity = Vector2.ZERO
	if cases[scenario].moving:
		var period := 360 if cases[scenario].get("obstructed",false) else 240
		var target := CENTER+Vector2(-150,-60) if simulation_ticks%period<period/2 else CENTER+Vector2(220,85)
		# The fixture's autopilot is not player gameplay work. Cache its route instead
		# of manufacturing an AStar query on every physics tick in the wall case.
		if target!=trainer_goal or simulation_ticks%24==0:
			trainer_route = world.navigation.path(trainer.position,target,trainer.body_radius)
			trainer_goal = target
		while not trainer_route.is_empty() and trainer.position.distance_to(trainer_route[0])<3: trainer_route.remove_at(0)
		if not trainer_route.is_empty(): trainer.velocity = trainer.position.direction_to(trainer_route[0])*minf(trainer.stats.value("speed"),trainer.position.distance_to(trainer_route[0])/delta)
		if trainer.position.distance_to(target)<6: trainer.velocity = Vector2.ZERO
	var before := trainer.position
	trainer.move_and_slide()
	if trainer.velocity.length_squared()>4: trainer.last_direction = trainer.velocity.normalized()
	if sample_started: movement_distance += before.distance_to(trainer.position)
	if sample_started and cases[scenario].get("obstructed",false):
		var side := int(signf(trainer.position.x-CENTER.x))
		if side!=previous_wall_side: wall_crossings += 1; previous_wall_side = side
	if sample_started and simulation_ticks%60==0:
		for actor in world.actors:
			clear_bodies = clear_bodies and world.navigation.point_clear(actor.position,maxf(0,actor.body_radius-2))
		population_samples.append({"seconds":simulation_ticks/60.0-warmup,"nodes":get_tree().get_node_count(),"orphans":int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),"projectiles":world.get_children().filter(func(node): return node is AbilityProjectile).size(),"particles":world.effects.particles.size()})
	if simulation_ticks%36==0:
		var target = TargetingSystem.nearest(trainer,world.actors,trainer.position,230)
		if target!=null: trainer.abilities.cast("ability.pulse",target)
	if simulation_ticks%45==0:
		for actor in session.party.active_actors:
			var target = TargetingSystem.nearest(actor,world.actors,actor.position,350)
			if target!=null: actor.abilities.cast(actor.ability_id(1),target)
	if simulation_ticks%120==1:
		for actor in enemies:
			actor.statuses.apply("status.burn",trainer)
			actor.statuses.apply("status.slow",trainer)
	trainer.presentation.tick(delta)
	if simulation_ticks>=roundi((warmup+duration)*60): transitioning = true

func _process(_delta: float) -> void:
	if scenario<0 or scenario>=cases.size(): return
	if transitioning and not sample_started: return
	if simulation_ticks<roundi(warmup*60): return
	var now := Time.get_ticks_usec()
	if not sample_started:
		metrics.begin(now,Engine.get_frames_drawn(),Engine.get_physics_frames())
		sample_started = true
		started_events = session.combat_events
		navigation_searches = session.world.navigation.searches
		starting_position = session.world.trainer.position
		CombatProfiler.reset()
		return
	var cpu := RenderingServer.get_frame_setup_time_cpu()
	var gpu := 0.0
	for viewport in [get_viewport(),session.world_viewport]:
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(viewport.get_viewport_rid())
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid())
	metrics.sample(now,Engine.get_frames_drawn(),Engine.get_physics_frames(),not headless and DisplayServer.window_is_focused(),cpu,gpu)
	draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	peak_nodes = maxi(peak_nodes,get_tree().get_node_count())
	peak_particles = maxi(peak_particles,session.world.effects.particles.size())
	peak_projectiles = maxi(peak_projectiles,session.world.get_children().filter(func(node): return node is AbilityProjectile).size())
	if transitioning: finish_scenario()

func finish_scenario() -> void:
	var result := metrics.report()
	result.merge(cases[scenario])
	result["simulation_seconds"] = (simulation_ticks-roundi(warmup*60))/60.0
	result["warmup_seconds"] = warmup
	result["alive_enemies"] = enemies.filter(func(actor): return is_instance_valid(actor) and actor.health.current>0).size()
	result["combat_events"] = session.combat_events-started_events
	result["navigation_searches"] = session.world.navigation.searches-navigation_searches
	result["movement_distance"] = movement_distance
	result["peak_nodes"] = peak_nodes
	result["peak_particles"] = peak_particles
	result["peak_projectiles"] = peak_projectiles
	result["draw_calls"] = FrameMetrics.distribution(draw_calls)
	result["renderer"] = RenderingServer.get_video_adapter_name()
	result["headless"] = headless
	result["effects_quality"] = Settings.effects_quality
	result["vsync_mode"] = DisplayServer.window_get_vsync_mode() if not headless else -1
	result["max_fps"] = Engine.max_fps
	result["window_size"] = [get_window().size.x,get_window().size.y]
	result["screen_refresh_hz"] = DisplayServer.screen_get_refresh_rate() if not headless else 0
	result["population_samples"] = population_samples.duplicate(true)
	result["clear_bodies"] = clear_bodies
	result["wall_crossings"] = wall_crossings
	result["companion_recoveries"] = session.party.active_actors.map(func(actor): return actor.brain.recovery_count)
	result["diagnostic_args"] = Array(OS.get_cmdline_user_args())
	result["source_hashes"] = source_hashes.duplicate()
	if CombatProfiler.enabled: result["script_sections"] = CombatProfiler.samples.duplicate(true)
	fixture_valid = fixture_valid and result.alive_enemies==int(cases[scenario].enemies) and result.combat_events>0 and absf(result.simulation_seconds-duration)<.02
	if cases[scenario].moving: fixture_valid = fixture_valid and movement_distance>duration*30 and session.world.drops.size()==120
	if cases[scenario].get("obstructed",false): fixture_valid = fixture_valid and result.navigation_searches>0 and clear_bodies
	if cases[scenario].get("obstructed",false) and duration>=10: fixture_valid = fixture_valid and wall_crossings>0
	sample_started = false
	# Stop new casts/ticks, then let actual projectile lifetimes and effect timers
	# expire. No forced projectile/effect deletion can hide a lifetime leak.
	session.world.set_physics_process(false)
	for actor in session.world.actors:
		actor.set_physics_process(false)
		actor.abilities.interrupt()
	for tick in 300: await get_tree().physics_frame
	var final_nodes := node_snapshot(get_tree().root)
	var voice_ids: Array[int] = []
	var audio_pool_valid := Audio.spatial_voices.size()<=Audio.VOICE_LIMIT
	for voice in Audio.spatial_voices:
		if not is_instance_valid(voice):
			audio_pool_valid = false
			continue
		voice_ids.append(voice.get_instance_id())
		audio_pool_valid = audio_pool_valid and voice.get_parent()==session.world and not voice.playing
	var unexpected_nodes: Array[Dictionary] = []
	for id in final_nodes:
		if not base_node_snapshot.has(id) and id not in voice_ids: unexpected_nodes.append(final_nodes[id])
	result["cleanup"] = {"base_nodes":base_nodes,"nodes":get_tree().get_node_count(),"base_orphans":base_orphans,"orphans":int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),"projectiles":session.world.get_children().filter(func(node): return node is AbilityProjectile).size(),"particles":session.world.effects.particles.size(),"rings":session.world.effects.rings.size(),"labels":session.world.effects.labels.size(),"hazards":session.world.hazards.size(),"base_audio_voices":base_audio_voices,"audio_voices":voice_ids.size(),"audio_pool_valid":audio_pool_valid,"unexpected_nodes":unexpected_nodes}
	var cleanup: Dictionary = result.cleanup
	# Audio intentionally retains a bounded reusable pool. Identify those exact nodes;
	# never subtract arbitrary AudioStreamPlayer2Ds or delete them to pass the check.
	result["cleanup_valid"] = cleanup.nodes-cleanup.audio_voices==cleanup.base_nodes-cleanup.base_audio_voices and cleanup.unexpected_nodes.is_empty() and cleanup.audio_pool_valid and cleanup.orphans<=cleanup.base_orphans and cleanup.projectiles==0 and cleanup.particles==0 and cleanup.rings==0 and cleanup.labels==0 and cleanup.hazards==0
	fixture_valid = fixture_valid and result.cleanup_valid
	var summary := result.duplicate()
	summary.erase("timeline")
	print("DURATION STRESS RESULT ",JSON.stringify(summary))
	reports.append(result)
	next_scenario.call_deferred()

func node_snapshot(node: Node) -> Dictionary:
	var script: Script = node.get_script()
	var snapshot := {node.get_instance_id():{"path":str(node.get_path()),"class":node.get_class(),"script":script.resource_path if script else ""}}
	for child in node.get_children(true): snapshot.merge(node_snapshot(child))
	return snapshot
