extends Node

var session
var actor: Actor
var target: Actor
var frame: int = 0
var seen: Dictionary = {}
var caption: Label
var real_dodges: int = 0
const DIRECTIONS := [Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT]

func _ready() -> void:
	session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	session.hud.close_panel()
	session.autosave_remaining = 100000
	session.hud.root.hide()
	session.world.set_physics_process(false)
	for value in session.world.actors:
		value.set_physics_process(false)
		value.presentation.hide()
	actor = session.world.trainer
	actor.presentation.show()
	actor.health.immortal = true
	actor.position = Vector2(550,600)
	session.world.camera.snap(actor.position)
	target = session.world.spawn_actor("species.briar",Factions.Team.WILD,actor.position+Vector2(0,100))
	target.set_physics_process(false)
	target.health.immortal = true
	target.presentation.hide()
	var overlay := CanvasLayer.new()
	add_child(overlay)
	caption = UIStyle.label("",18,UIStyle.PAPER)
	caption.position = Vector2(24,24)
	caption.add_theme_color_override("font_shadow_color",Color.BLACK)
	caption.add_theme_constant_override("shadow_outline_size",4)
	overlay.add_child(caption)

func _physics_process(delta: float) -> void:
	frame += 1
	if frame>1200:
		if frame==1201: Audio.shutdown()
		if frame==1206:
			var valid := real_dodges==4
			for record in seen.values():
				valid = valid and record.has_all(["windup","release","hurt","dodge","walk"])
				if valid: valid = record.windup.size()==2 and record.release.size()==2 and record.walk.size()==6 and record.hurt.size()==3 and record.dodge.size()==3
			print("HERO COMBAT MOTION ",JSON.stringify(seen)," real_dodges=",real_dodges," verified=",valid)
			get_tree().quit(0 if valid else 1)
		return
	var cycle := (frame-1)/300
	var local := (frame-1)%300
	var direction: Vector2 = DIRECTIONS[cycle]
	var animation := actor.presentation.character_animation
	if local==0:
		actor.abilities.interrupt()
		actor.combat.rest()
		actor.position = Vector2(550,600)
		actor.velocity = Vector2.ZERO
		animation.previous_position = actor.position
		animation.face(direction)
		target.position = actor.position+direction*100
		session.world.camera.snap(actor.position)
		seen[cycle] = {}
	actor.combat.tick(delta)
	actor.abilities.tick(delta)
	actor.velocity = Vector2.ZERO
	var action := "Покой"
	if local==30 or local==160:
		target.position = actor.position+direction*(100 if local==30 else -100)
		actor.abilities.cooldowns.reset()
		actor.abilities.cast("ability.pulse",target)
	if local>=30 and local<65: action = "Подготовка → выпуск → возврат"
	if local==80: actor.presentation.hit()
	if local>=80 and local<95: action = "Реакция на попадание"
	if local==115:
		actor.last_direction = direction
		Input.action_press("dodge")
	if local==116: Input.action_release("dodge")
	if local>=115 and local<=130:
		var energy_before := actor.energy.current
		actor.player_tick(delta)
		actor.move_and_slide()
		if actor.dodge_time>0 and is_equal_approx(energy_before-actor.energy.current,24.0) and actor.dodge_cooldown>0:
			real_dodges += 1
			print("HERO DODGE direction=",cycle," frame=",local," energy_spent=",energy_before-actor.energy.current)
		action = "Рывок"
	if local>=155 and local<245:
		actor.velocity = direction*120
		actor.last_direction = direction
		actor.position += actor.velocity*delta
		action = "Атака и попадание на ходу · шаги продолжаются"
		if local==185: actor.presentation.hit()
	actor.presentation.tick(delta)
	caption.text = ["Спереди","Вправо","Со спины","Влево"][cycle]+" · "+action
	if not seen[cycle].has(animation.current_clip): seen[cycle][animation.current_clip] = {}
	seen[cycle][animation.current_clip][animation.action_frame if animation.action_frame>=0 else animation.previous_frame] = true
	if local in [31,38,44,51,80,85,90,115,119,124,192]: capture.call_deferred(cycle,local)

func capture(cycle: int, local: int) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/hero-reactions-%d-%d.png"%[cycle,local])
