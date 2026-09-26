extends Node

var count: int = 0
var failures: Array[String] = []

func _ready() -> void: run.call_deferred()

func check(condition: bool, label: String) -> void:
	count += 1
	if not condition: failures.append(label)
	print("ITEM OWNERSHIP ",condition," ",label)

func run() -> void:
	var session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	session.autosave_remaining = 100000
	preload("res://tests/item_ownership_checks.gd").new().run(session,check)
	Audio.shutdown()
	for frame in 5: await get_tree().process_frame
	print("ITEM OWNERSHIP RUNTIME checks=",count," verified=",failures.is_empty())
	get_tree().quit(0 if failures.is_empty() else 1)
