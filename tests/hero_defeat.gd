extends Node

var session
var frame: int = 0
var seen: Dictionary = {}
var frozen_at := Vector2.ZERO
var valid: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	session.hud.close_panel()
	session.autosave_remaining = 100000
	session.hud.notification.position.y = 365
	prepare(0)

func prepare(index: int) -> void:
	var actor: Actor = session.world.trainer
	actor.set_physics_process(false)
	actor.position = Vector2(550,600)
	actor.last_direction = [Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][index]
	actor.velocity = actor.last_direction*90
	actor.presentation.character_animation.previous_position = actor.position-actor.last_direction*2
	actor.presentation.tick(1.0/60)
	actor.velocity = Vector2.ZERO
	session.world.camera.snap(actor.position)
	session.hud.notify("Падение · "+["спереди","вправо","со спины","влево"][index])
	seen[index] = {}

func _process(_delta: float) -> void:
	frame += 1
	var cycle := (frame-1)/140
	var local := (frame-1)%140
	if frame<=560:
		var actor: Actor = session.world.trainer
		if local==25:
			frozen_at = actor.position
			actor.health.invulnerable = 0
			actor.health.damage(100000)
		if local>=25 and local<=95:
			seen[cycle][actor.presentation.character_animation.defeat_frame] = true
			valid = valid and actor.position==frozen_at and get_tree().paused
		if local in [32,52,72,90]: capture.call_deferred(cycle,local)
		if local==100:
			valid = valid and session.hud.panel.visible and seen[cycle].size()==6
		if local==139:
			session.revive()
			if cycle<3: prepare(cycle+1)
	if frame==570: Audio.shutdown()
	if frame==580:
		print("HERO DEFEAT ",JSON.stringify(seen)," verified=",valid)
		get_tree().quit(0 if valid else 1)

func capture(cycle: int, local: int) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/hero-defeat-%d-%d.png"%[cycle,local])
