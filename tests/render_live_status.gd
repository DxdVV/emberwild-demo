extends Node

var session
var source: Actor
var observed_frames: Dictionary = {}
var failure: bool = false

func _ready() -> void: run.call_deferred()

func capture(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/live-status-"+name+".png")

func verify(condition: bool, text: String) -> void:
	print("LIVE STATUS ",text," verified=",condition)
	if not condition: failure = true

func run() -> void:
	get_viewport().gui_embed_subwindows = true
	session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	session.autosave_remaining = 100000
	session.hud.close_panel()
	session.change_area("area.grove",false)
	for actor in session.world.actors.duplicate():
		if Factions.hostile(actor.faction,Factions.Team.TRAINER): session.world.remove_actor(actor)
	var trainer: Actor = session.world.trainer
	trainer.position = Vector2(570,510)
	trainer.health.immortal = true
	session.world.camera.snap(trainer.position)
	source = session.world.spawn_actor("species.briar",Factions.Team.WILD,trainer.position+Vector2(150,-25))
	source.set_physics_process(false)
	source.health.immortal = true
	session.world.focus_target = source
	for actor in session.party.active_actors:
		actor.position = trainer.position+Vector2(-60,30) if actor==session.party.active_actors[0] else trainer.position+Vector2(60,40)
		actor.brain.mode = ActorBrain.Mode.HOLD
		actor.health.immortal = true
	for id in Database.statuses: trainer.statuses.apply(id,source)
	trainer.statuses.apply("status.burn",source)
	trainer.health.shield = 32
	session.party.active_actors[0].statuses.apply("status.burn",source)
	session.party.active_actors[0].statuses.apply("status.burn",source)
	session.party.active_actors[0].health.shield = 18
	session.party.active_actors[1].statuses.apply("status.wet",source)
	session.party.active_actors[1].statuses.apply("status.slow",source)
	source.statuses.apply("status.wet",trainer)
	source.statuses.apply("status.marked",trainer)
	session.hud.refresh_status_strips()
	await capture("all")
	verify(session.hud.status_strips[0].badges.size()==8,"all seven shapes and shield in one row")
	var tick_before: float = trainer.statuses.entries["status.burn"].remaining
	for frame in 180:
		Input.action_press("move_right" if frame<90 else "move_left")
		Input.action_release("move_left" if frame<90 else "move_right")
		await get_tree().physics_frame
		source.combat.tick(1.0/60)
		observed_frames[trainer.presentation.character_animation.previous_frame] = true
	Input.action_release("move_left")
	Input.action_release("move_right")
	session.hud.refresh_status_strips()
	await capture("countdown")
	verify(not trainer.statuses.entries.has("status.root") and trainer.statuses.entries["status.burn"].remaining<tick_before-2.5,"live expiry and countdown while moving")
	verify(observed_frames.size()>=4,"stepping continues after root expires")
	trainer.statuses.apply("status.burn",source,4)
	session.hud.refresh_status_strips()
	var motion := InputEventMouseMotion.new()
	motion.position = session.hud.status_strips[0].global_position+Vector2(38,25)
	get_viewport().push_input(motion,true)
	for frame in 45: await get_tree().process_frame
	var hover := find_hover(get_tree().root)
	verify(hover!=null and hover.description.text.begins_with(tr("status.burn")),"native hover opens the live effect tooltip")
	await capture("hover")
	var strip: StatusStrip = session.hud.status_strips[0]
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = strip.global_position+Vector2(8,25)
	click.pressed = true
	get_viewport().push_input(click,true)
	var release := click.duplicate()
	release.pressed = false
	get_viewport().push_input(release,true)
	await get_tree().process_frame
	verify(get_tree().paused and session.hud.panel.visible,"native badge click opens paused inspection")
	await capture("clicked")
	session.hud.close_panel()
	TranslationServer.set_locale("en")
	trainer.statuses.apply("status.slow",source)
	session.hud.refresh_status_strips()
	await capture("english")
	TranslationServer.set_locale("ru")
	Audio.shutdown()
	for frame in 5: await get_tree().process_frame
	print("LIVE STATUS RENDER COMPLETE success=",not failure)
	get_tree().quit(1 if failure else 0)

func find_hover(node: Node) -> StatusHover:
	if node is StatusHover: return node
	for child in node.get_children():
		var found := find_hover(child)
		if found!=null: return found
	return null
