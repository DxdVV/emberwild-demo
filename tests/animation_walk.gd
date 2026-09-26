extends Node

var session
var frames: int = 0
var observed: Dictionary = {}
var moving_cast_frames: Dictionary = {}
var target: Actor

func _ready() -> void:
	session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	session.hud.close_panel()
	session.autosave_remaining = 100000
	session.world.trainer.health.immortal = true
	session.world.trainer.position = Vector2(430,510)
	session.world.camera.snap(session.world.trainer.position)
	session.hud.notify("Шаги · четыре направления · атака на ходу · рывок")

func _physics_process(_delta: float) -> void:
	frames += 1
	var controls := ["move_right","move_down","move_left","move_up","dodge","attack"]
	for action in controls: Input.action_release(action)
	if frames<90: Input.action_press("move_right")
	elif frames<150: Input.action_press("move_down")
	elif frames<230: Input.action_press("move_left")
	elif frames<290: Input.action_press("move_up")
	elif frames==340: Input.action_press("dodge")
	elif frames>=370 and frames<460:
		Input.action_press("move_right")
		Input.action_press("attack")
	if frames==295:
		target = session.world.spawn_actor("species.briar",Factions.Team.WILD,session.world.trainer.position+Vector2(130,0))
		target.set_physics_process(false)
		target.health.immortal = true
		session.world.trainer.last_direction = Vector2.RIGHT
		session.world.trainer.abilities.cast("ability.pulse",target)
	if frames>=370 and frames<460 and is_instance_valid(target):
		target.position = session.world.trainer.position+Vector2(140,0)
		session.world.focus_target = target
	observed[session.world.trainer.presentation.character_animation.previous_frame] = true
	if frames>375 and frames<460 and session.world.trainer.abilities.phase!=AbilityController.Phase.IDLE:
		moving_cast_frames[session.world.trainer.presentation.character_animation.previous_frame] = true
	if frames in [60,110,195,270,305,345,410]: capture_frame.call_deferred(frames)
	if frames==515: Audio.shutdown()
	if frames==520:
		print("ANIMATION distinct observed frames=",observed.keys())
		print("ANIMATION moving cast frames=",moving_cast_frames.keys())
		if observed.size()<12 or moving_cast_frames.size()<3:
			push_error("Walking did not exercise directional animation frames")
			get_tree().quit(1)
		else: get_tree().quit()

func capture_frame(index: int) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/movement-%03d.png"%index)
