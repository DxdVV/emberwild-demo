extends Node

var session
var failed: bool = false
var results: Array[Dictionary] = []

func _ready() -> void: run.call_deferred()

func frames(amount: int) -> void:
	for index in amount: await get_tree().physics_frame

func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/hazard-avoidance-"+name+".png")

func run() -> void:
	session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	session.autosave_remaining = 100000
	session.hud.close_panel(true)
	session.change_area("area.grove",false)
	var world: GameWorld = session.world
	world.set_physics_process(false)
	for actor in world.actors.duplicate():
		if Factions.hostile(actor.faction,Factions.Team.TRAINER): world.remove_actor(actor)
		else: actor.set_physics_process(false)
	world.trainer.position = Vector2(1030,990)
	world.camera.snap(Vector2(1190,1000))
	world.camera.cinematic = true
	await frames(3)
	for name in ["single","overlap","wall","hold","friendly","cancelled"]: await run_case(name)
	Audio.shutdown()
	await frames(5)
	var file := FileAccess.open("res://build/hazard-avoidance-runtime.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"))
	file.close()
	print("HAZARD AVOIDANCE RUNTIME verified=",not failed)
	get_tree().quit(1 if failed else 0)

func run_case(name: String) -> void:
	var world: GameWorld = session.world
	var ally: Actor = session.party.active_actors[0]
	ally.set_physics_process(false)
	ally.position = Vector2(1190,1000)
	ally.combat.rest()
	ally.presentation.recover()
	ally.brain.escape_goal = Vector2.INF
	ally.brain.escape_retry_remaining = 0
	ally.brain.route.clear()
	ally.brain.route_remaining = 0
	ally.brain.mode = ActorBrain.Mode.HOLD if name=="hold" else ActorBrain.Mode.AGGRESSIVE
	var source := world.spawn_actor("species.guardian",Factions.Team.BOSS,Vector2(1190,790))
	source.set_physics_process(false)
	var origin := ally.position
	var initial_hp := ally.health.current
	var searches := world.navigation.searches
	var original_obstacles := world.navigation.obstacles.duplicate()
	var wall: StaticBody2D
	if name=="wall":
		var blocked := Rect2(1210,920,30,160)
		var obstacles := original_obstacles.duplicate()
		obstacles.append(blocked)
		world.navigation.configure(world.area.size,obstacles)
		searches = 0
		wall = StaticBody2D.new()
		wall.position = blocked.get_center()
		wall.collision_layer = 1
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = blocked.size
		shape.shape = rectangle
		wall.add_child(shape)
		world.add_child(wall)
	var source_actor: Actor = world.trainer if name=="friendly" else source
	world.hazard(source_actor,origin,95,1.1)
	if name=="overlap":
		world.hazard(source,origin+Vector2(55,0),95,1.28)
		world.hazard(source,origin+Vector2(-20,-45),95,1.46)
	if name=="cancelled": world.remove_actor(source)
	ally.set_physics_process(true)
	var evade_seen := false
	var in_bounds := true
	var teleported := false
	var poses: Dictionary = {}
	var previous := ally.position
	for tick in 115:
		await get_tree().physics_frame
		evade_seen = evade_seen or ally.brain.state==ActorBrain.State.EVADE
		in_bounds = in_bounds and world.navigation.point_clear(ally.position,ally.body_radius)
		teleported = teleported or previous.distance_to(ally.position)>8
		previous = ally.position
		if ally.velocity.length()>10: poses[ally.presentation.creature_animation.current_frame] = true
		if tick in [30,61,90]: await capture(name+"-"+str(tick))
	var success: bool
	if name in ["single","overlap","wall"]: success = evade_seen and is_equal_approx(ally.health.current,initial_hp) and not teleported and in_bounds and poses.size()>=4
	elif name=="hold": success = not evade_seen and ally.position.distance_to(origin)<1 and ally.health.current<initial_hp
	else: success = not evade_seen and is_equal_approx(ally.health.current,initial_hp)
	success = success and world.hazards.is_empty() and world.navigation.searches-searches<15
	var result := {"case":name,"success":success,"evade":evade_seen,"health_before":initial_hp,"health_after":ally.health.current,"walk_poses":poses.size(),"clear_motion":in_bounds and not teleported,"path_searches":world.navigation.searches-searches,"hazards_remaining":world.hazards.size()}
	results.append(result)
	print("HAZARD AVOIDANCE ",JSON.stringify(result))
	failed = failed or not success
	ally.set_physics_process(false)
	if is_instance_valid(source): world.remove_actor(source)
	if is_instance_valid(wall):
		wall.queue_free()
		world.navigation.configure(world.area.size,original_obstacles)
	await frames(3)
