extends Node

var failures: int = 0
var checks: int = 0

func _ready() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print("LOOT HUD ",label," verified=",value)

func run() -> void:
	var session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	session.hud.close_panel()
	session.autosave_remaining = 100000
	await preload("res://tests/loot_hud_checks.gd").new().run(session,check)
	Audio.shutdown()
	for frame in 4: await get_tree().process_frame
	print("LOOT HUD RUNTIME checks=",checks," verified=",failures==0)
	get_tree().quit(0 if failures==0 else 1)
