extends Node

class Arena extends Node2D:
	var walls: Array[Rect2] = []
	func _draw() -> void:
		for wall in walls:
			draw_rect(wall,Color("394740"))
			for x in range(int(wall.position.x),int(wall.end.x),16):
				for y in range(int(wall.position.y),int(wall.end.y),16):
					draw_rect(Rect2(x+1,y+1,minf(14,wall.end.x-x-1),minf(14,wall.end.y-y-1)),Color("667165"))

var session
var subject: Actor
var arena: Arena
var stage: int = -1
var frame: int = 0
var results: Array = []
var goal := Vector2.ZERO
var held_at := Vector2.ZERO
var clear_steps: bool = true
var seen_frames: Dictionary = {}
var started_searches: int = 0
var previous_position := Vector2.ZERO
var max_step: float = 0
var caption: Label

func _ready() -> void:
	CombatProfiler.enabled = true
	session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	session.hud.close_panel()
	session.hud.root.hide()
	session.autosave_remaining = 100000
	session.world.set_physics_process(false)
	session.world.trainer.set_physics_process(false)
	session.world.trainer.health.immortal = true
	for actor in session.world.actors.duplicate():
		if actor!=session.world.trainer: session.world.remove_actor(actor)
	session.party.active_actors.clear()
	for node in session.world.entity_layer.get_children():
		if node is WorldEnvironment2D: node.queue_free()
	session.world.camera.target = null
	session.world.camera.snap(Vector2(800,610))
	var layer := CanvasLayer.new()
	add_child(layer)
	caption = UIStyle.label("",18,UIStyle.PAPER)
	caption.position = Vector2(24,25)
	caption.add_theme_color_override("font_shadow_color",Color.BLACK)
	caption.add_theme_constant_override("shadow_outline_size",4)
	layer.add_child(caption)
	setup_stage()

func setup_stage() -> void:
	stage += 1
	frame = 0
	clear_steps = true
	seen_frames.clear()
	max_step = 0
	if is_instance_valid(arena): arena.queue_free()
	if is_instance_valid(subject): session.world.remove_actor(subject)
	for actor in session.world.actors.duplicate():
		if actor!=session.world.trainer: session.world.remove_actor(actor)
	arena = Arena.new()
	var start := Vector2(600,610)
	goal = Vector2(1000,610)
	match stage:
		0:
			arena.walls = [Rect2(730,480,90,250)]
			caption.text = "Обход стены · реальная коллизия · шаги по пройденному пути"
		1:
			arena.walls = [Rect2(760,0,40,574),Rect2(760,638,40,562)]
			caption.text = "Узкий проход · ширина 64 · тело спутника 28"
		2:
			arena.walls = [Rect2(730,480,90,250)]
			caption.text = "Смена направления следования во время обхода"
		3:
			arena.walls = [Rect2(570,550,95,90)]
			start = Vector2(1390,900)
			goal = Vector2(675,540)
			caption.text = "Возврат потерявшегося спутника · свободное место у героя"
		4:
			start = Vector2(1000,610)
			goal = Vector2(160,150)
			caption.text = "Удерживать позицию · герой далеко · враг рядом"
		5:
			arena.walls = [Rect2(760,0,40,574),Rect2(760,638,40,562)]
			caption.text = "Большое тело · узкий проход недоступен · остановка перед стеной"
	session.world.add_child(arena)
	for rect in arena.walls:
		var body := StaticBody2D.new()
		body.position = rect.get_center()
		body.collision_layer = 1
		body.collision_mask = 0
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		collision.shape = shape
		body.add_child(collision)
		arena.add_child(body)
	session.world.navigation.configure(Vector2(1600,1200),arena.walls)
	session.world.navigation.grid_for(14)
	subject = session.world.spawn_actor("species.guardian" if stage==5 else "species.cinder",Factions.Team.BOSS if stage==5 else Factions.Team.COMPANION,start)
	subject.brain.mode = ActorBrain.Mode.HOLD if stage==4 else ActorBrain.Mode.FOLLOW
	subject.health.immortal = true
	subject.set_physics_process(false)
	var offset := subject.brain.follow_offset()
	session.world.trainer.position = goal-offset
	if stage==3: session.world.trainer.position = Vector2(650,530)
	if stage==5:
		session.world.trainer.position = Vector2(1390,900)
		subject.spawn_origin = goal
	if stage==4:
		var enemy: Actor = session.world.spawn_actor("species.rill",Factions.Team.WILD,start+Vector2(50,0))
		enemy.health.immortal = true
		enemy.set_physics_process(false)
	held_at = start
	previous_position = start
	started_searches = session.world.navigation.searches

func _physics_process(_delta: float) -> void:
	frame += 1
	if frame==4: subject.set_physics_process(true)
	if frame<5: return
	if stage==2 and frame==110:
		goal = Vector2(540,820)
		var offset := subject.brain.follow_offset()
		session.world.trainer.position = goal-offset
	var at := subject.position
	clear_steps = clear_steps and session.world.navigation.point_clear(at,subject.body_radius)
	max_step = maxf(max_step,at.distance_to(previous_position))
	previous_position = at
	seen_frames[subject.presentation.creature_animation.current_frame] = true
	if frame in [100,210,340]: capture.call_deferred()
	var duration := 390 if stage<3 else 180
	if frame>=duration:
		var searches: int = session.world.navigation.searches-started_searches
		var reached := at.distance_to(goal)<45 if stage<3 else (subject.brain.recovery_count==1 if stage==3 else at.distance_to(held_at)<.1)
		if stage==5: reached = at.x<760-subject.body_radius and at.distance_to(goal)>100
		var valid := clear_steps and reached
		if stage<3: valid = valid and subject.brain.recovery_count==0 and max_step<10 and searches<35 and seen_frames.size()>=6
		if stage==4: valid = valid and subject.brain.recovery_count==0
		if stage in [3,5]: valid = valid and searches<15
		results.append({"stage":stage,"clear":clear_steps,"reached":reached,"searches":searches,"recovery_count":subject.brain.recovery_count,"largest_step":max_step,"frames":seen_frames.size(),"valid":valid})
		if stage<5: setup_stage()
		else:
			var passed := results.all(func(result): return result.valid)
			var headless := DisplayServer.get_name()=="headless"
			var report := {"cases":results,"verified":passed,"headless":headless,"profile":CombatProfiler.samples}
			FileAccess.open("res://build/navigation-runtime-headless.json" if headless else "res://build/navigation-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
			print("NAVIGATION RUNTIME ",JSON.stringify(results)," verified=",passed)
			Audio.shutdown()
			get_tree().quit(0 if passed else 1)

func capture() -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/navigation-%d-%d.png"%[stage,frame])
