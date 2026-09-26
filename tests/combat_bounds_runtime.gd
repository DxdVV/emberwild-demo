extends Node

var count: int = 0
var failures: int = 0

func _ready() -> void: run.call_deferred()

func run() -> void:
	var session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	preload("res://tests/combat_bounds_checks.gd").new().run(session,check)
	Audio.shutdown()
	for tick in 4: await get_tree().process_frame
	print("COMBAT BOUNDS checks=",count," failures=",failures)
	get_tree().quit(0 if failures==0 else 1)

func check(value: bool, label: String) -> void:
	count += 1
	if not value: failures += 1
	print("COMBAT BOUNDS ",label," verified=",value)
