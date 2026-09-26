extends Node

var session
var tools_panel: Window

func _ready() -> void:
	session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	session.hud.close_panel()
	session.world.trainer.health.immortal = true
	session.hud.notify("Боевая комната · F3: инструменты, spawn/level/status/item/teleport")
	session.hud.show_debug()
