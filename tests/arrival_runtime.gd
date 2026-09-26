extends Node

var session
var checks: int = 0
var failures: Array[String] = []

func _ready() -> void: run.call_deferred()

func check(condition: bool, title: String) -> void:
	checks += 1
	if not condition: failures.append(title)
	print("ARRIVAL ",condition," ",title)

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	session.world.camera.snap(session.world.trainer.position)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/arrival-"+label+".png")

func run() -> void:
	session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	session.autosave_remaining = 100000
	await preload("res://tests/arrival_checks.gd").new().run(session,check,capture)
	Audio.shutdown()
	for frame in 5: await get_tree().process_frame
	print("ARRIVAL RUNTIME checks=",checks," verified=",failures.is_empty()," failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
