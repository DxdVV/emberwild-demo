extends Node

var failed: bool = false

func _ready() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	failed = failed or not value
	print("VALIDATION VIEWER ",label," verified=",value)

func capture(label: String) -> void:
	for frame in 4: await get_tree().process_frame
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/validation-viewer-"+label+".png")

func run() -> void:
	var viewer = load("res://debug/ContentViewer.tscn").instantiate()
	add_child(viewer)
	viewer.show_validation()
	await capture("valid")
	var texts := preload("res://tests/localization_checks.gd").new()
	check(texts.texts(viewer.preview).has("Ошибок: 0"),"valid loaded content report")
	var original: float = Database.abilities["ability.spark"].windup
	Database.abilities["ability.spark"].windup = NAN
	viewer.show_validation()
	await capture("invalid")
	check(texts.texts(viewer.preview).any(func(line): return "abilities/spark.tres" in line and "windup" in line),"invalid report names exact resource and field")
	Database.abilities["ability.spark"].windup = original
	viewer.show_validation()
	await capture("repaired")
	check(Database.errors.is_empty() and texts.texts(viewer.preview).has("Ошибок: 0"),"repair clears previous errors")
	Audio.shutdown()
	for frame in 4: await get_tree().process_frame
	print("VALIDATION VIEWER COMPLETE verified=",not failed)
	get_tree().quit(1 if failed else 0)
