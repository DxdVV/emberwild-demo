extends Node

var session
var goals: Array[Vector2] = []
var next: int = 0
var frames: int = 0
var held_frames: int = 30
var phase: int = 0
var reached: Array[int] = [0,0]
var walk_frames := {}
var valid: bool = true
var caption: Label
var finishing: bool = false

func _ready() -> void:
	session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	session.autosave_remaining = 100000
	session.hud.close_panel()
	var layer := CanvasLayer.new()
	add_child(layer)
	caption = UIStyle.label("Проверка проходов · противники неподвижны",12,UIStyle.GOLD)
	caption.position = Vector2(270,18)
	layer.add_child(caption)
	prepare_area("area.haven")

func prepare_area(id: String) -> void:
	session.change_area(id,false)
	session.world.set_physics_process(false)
	session.world.trainer.set_physics_process(false)
	for actor in session.world.actors:
		if actor.faction>=Factions.Team.WILD: actor.set_physics_process(false)
		elif actor.brain!=null: actor.brain.mode = ActorBrain.Mode.FOLLOW
	goals.clear()
	next = 0
	var layout: AreaLayout = session.world.area.layout
	if phase==0:
		for interaction in layout.interactions: goals.append(AreaLayout.point(interaction.at))
	else:
		for point in layout.paths[0].points: goals.append(AreaLayout.point(point))
		for point in layout.paths[1].points: goals.append(AreaLayout.point(point))
		var lower: Array = layout.paths[2].points.duplicate()
		lower.reverse()
		for point in lower: goals.append(AreaLayout.point(point))
		for point in layout.paths[3].points: goals.append(AreaLayout.point(point))
		goals.append(layout.entry)
	held_frames = 30
	capture.call_deferred("layout-"+("haven" if phase==0 else "entry"))

func _physics_process(delta: float) -> void:
	if finishing: return
	frames += 1
	if frames>4200:
		valid = false
		finish()
		return
	var actor: Actor = session.world.trainer
	if held_frames>0:
		held_frames -= 1
		actor.velocity = Vector2.ZERO
		actor.presentation.tick(delta)
		return
	if next>=goals.size():
		if phase==0:
			phase = 1
			prepare_area("area.grove")
		else: finish()
		return
	var goal := goals[next]
	if actor.position.distance_to(goal)<8:
		reached[phase] += 1
		if phase==1 and next in [3,6,8,10,14,16]:
			capture.call_deferred("layout-grove-%02d"%next)
			held_frames = 30
		next += 1
		return
	var direction: Vector2 = session.world.navigation.direction(actor.position,goal)
	var before := actor.position
	actor.velocity = direction*minf(actor.stats.value("speed"),actor.position.distance_to(goal)/delta)
	if direction!=Vector2.ZERO: actor.last_direction = direction
	actor.move_and_slide()
	valid = valid and session.world.navigation.point_clear(actor.position) and before.distance_to(actor.position)<6
	actor.presentation.tick(delta)
	walk_frames[actor.presentation.character_animation.previous_frame] = true

func finish() -> void:
	finishing = true
	var clear_motion := valid
	valid = valid and reached[0]==3 and reached[1]==20 and walk_frames.size()>=12
	print("LAYOUT RUNTIME ",JSON.stringify({"reached":reached,"walking_frames":walk_frames.size(),"physics_frames":frames,"clear_motion":clear_motion})," verified=",valid)
	Audio.shutdown()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if valid else 1)

func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/"+name+".png")
