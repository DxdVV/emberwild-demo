extends Node

var session
var subjects: Array[Actor] = []
var targets: Array[Actor] = []
var frame: int = 0
var seen: Dictionary = {}

func _ready() -> void:
	session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	session.hud.close_panel()
	session.autosave_remaining = 100000
	session.world.set_physics_process(false)
	for actor in session.world.actors: actor.set_physics_process(false)
	session.world.trainer.position = Vector2(600,600)
	session.world.trainer.health.immortal = true
	session.world.camera.target = null
	session.world.camera.snap(Vector2(650,420))
	for index in 5:
		var id: String = ["species.cinder","species.rill","species.briar","species.volt","species.guardian"][index]
		var actor: Actor = session.world.spawn_actor(id,Factions.Team.WILD,Vector2(280+index*175,540))
		actor.set_physics_process(false)
		subjects.append(actor)
		var target: Actor = session.world.spawn_actor("species.cinder",Factions.Team.COMPANION,actor.position+Vector2(70,15))
		target.presentation.hide()
		target.health.immortal = true
		target.set_physics_process(false)
		targets.append(target)
	session.hud.notify("Существа: шаги → подготовка → удар → попадание → падение")

func _physics_process(delta: float) -> void:
	frame += 1
	for index in subjects.size():
		var actor := subjects[index]
		if not is_instance_valid(actor): continue
		actor.combat.tick(delta)
		actor.abilities.tick(delta)
		actor.brain.special_remaining = maxf(0,actor.brain.special_remaining-delta)
		actor.velocity = Vector2(55,0) if frame<80 else Vector2.ZERO
		if frame<80: actor.position += actor.velocity*delta
		if frame==90: actor.abilities.cast(actor.species.abilities[0],targets[index])
		if frame==180: actor.abilities.cast(actor.species.abilities[1],targets[index])
		if frame==280:
			actor.presentation.hit()
			actor.health.damage(5)
		if frame==340: actor.health.damage(1000000)
		actor.presentation.tick(delta)
		seen[actor.presentation.creature_animation.current_clip] = true
	if frame==120:
		var boss := subjects[4]
		boss.faction = Factions.Team.BOSS
		boss.brain.boss_time = 0
		boss.brain.boss_tick(delta,targets[4])
	if frame in [65,155,188,282,351,380]: capture.call_deferred(frame)
	if frame==445: Audio.shutdown()
	if frame==450:
		print("CREATURE ANIMATION clips=",seen.keys())
		get_tree().quit(0 if seen.has_all(["walk","windup","release","hurt","death"]) else 1)

func capture(index: int) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/creatures-%03d.png"%index)
