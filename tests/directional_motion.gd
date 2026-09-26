extends Node

var session
var subjects: Array[Actor] = []
var targets: Array[Actor] = []
var frame: int = 0
var seen: Dictionary = {}
var caption: Label

func _ready() -> void:
	session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	session.hud.close_panel()
	session.autosave_remaining = 100000
	session.hud.root.hide()
	var world: GameWorld = session.world
	world.set_physics_process(false)
	for actor in world.actors:
		actor.set_physics_process(false)
		actor.presentation.hide()
	for node in world.entity_layer.get_children():
		if node is WorldEnvironment2D: node.hide()
	world.camera.target = null
	world.camera.snap(Vector2(650,450))
	for index in 4:
		var id: String = ["cinder","rill","briar","volt"][index]
		var actor := world.spawn_actor("species."+id,Factions.Team.WILD,Vector2(330+index*205,480))
		actor.set_physics_process(false)
		subjects.append(actor)
		var target := world.spawn_actor("species.cinder",Factions.Team.COMPANION,actor.position+Vector2(0,100))
		target.presentation.hide()
		target.health.immortal = true
		target.set_physics_process(false)
		targets.append(target)
		seen[id] = {}
	var overlay := CanvasLayer.new()
	add_child(overlay)
	caption = UIStyle.label("",19,UIStyle.PAPER)
	caption.position = Vector2(24,22)
	caption.add_theme_color_override("font_shadow_color",Color.BLACK)
	caption.add_theme_constant_override("shadow_outline_size",4)
	overlay.add_child(caption)

func _physics_process(delta: float) -> void:
	frame += 1
	var direction := Vector2.ZERO
	if frame<=90: direction = Vector2.DOWN; caption.text = "Шаги к зрителю · отдельные кадры лап и крыльев"
	elif frame<=180: direction = Vector2.UP; caption.text = "Шаги от зрителя · вид со спины"
	elif frame<=270: direction = Vector2.LEFT; caption.text = "Поворот влево"
	elif frame<=360: direction = Vector2.RIGHT; caption.text = "Поворот вправо"
	elif frame<=402: caption.text = "Подготовка и удар от зрителя"
	elif frame<=445: caption.text = "Подготовка и удар к зрителю"
	elif frame<=489: direction = Vector2.UP; caption.text = "Атака на ходу сохраняет шаги"
	elif frame<=525: caption.text = "Остановка и реакция на попадание"
	else: caption.text = "Падение в текущем направлении · опора на землю"
	for index in subjects.size():
		var actor := subjects[index]
		if not is_instance_valid(actor): continue
		actor.combat.tick(delta)
		actor.abilities.tick(delta)
		actor.velocity = direction*70
		if direction!=Vector2.ZERO:
			actor.position += actor.velocity*delta
			actor.last_direction = direction
		if frame in [365,407,450]:
			targets[index].position = actor.position+Vector2(0,-100 if frame==365 else 100)
			actor.abilities.cooldowns.reset()
			actor.abilities.cast(actor.ability_id(0),targets[index])
		if frame==500: actor.presentation.hit()
		if frame==526: actor.health.damage(1000000)
		actor.presentation.tick(delta)
		var motion := actor.presentation.creature_animation
		seen[str(actor.species.id).trim_prefix("species.")][motion.facing+":"+motion.current_clip] = true
	if frame in [60,145,198,300,371,383,414,429,467,503,570]: capture.call_deferred(frame)
	if frame==595: Audio.shutdown()
	if frame==600:
		var required := ["south:walk","north:walk","east:walk","north:windup","north:release","south:windup","south:release","north:hurt","north:death"]
		var valid := seen.values().all(func(states): return states.has_all(required))
		print("DIRECTIONAL ANIMATION ",JSON.stringify(seen)," verified=",valid)
		get_tree().quit(0 if valid else 1)

func capture(index: int) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/directions-%03d.png"%index)
