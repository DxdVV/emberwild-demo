extends Node

var session
var subjects: Array[Actor] = []
var targets: Array[Actor] = []
var seen: Array[Dictionary] = [{},{},{}]
var frame: int = 0
var caption: Label
var preserved: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	session.hud.close_panel()
	session.autosave_remaining = 100000
	session.world.set_physics_process(false)
	for actor in session.world.actors: actor.set_physics_process(false)
	session.party.roster[0].level = 5
	session.party.roster[0].refresh_stats()
	session.hud.show_party()
	var overlay := CanvasLayer.new()
	add_child(overlay)
	caption = UIStyle.label("",17,UIStyle.PAPER)
	caption.position = Vector2(24,22)
	caption.add_theme_color_override("font_shadow_color",Color.BLACK)
	caption.add_theme_constant_override("shadow_outline_size",4)
	overlay.add_child(caption)

func build_stage() -> void:
	session.hud.close_panel()
	session.hud.root.hide()
	for actor in session.world.actors: actor.presentation.hide()
	for node in session.world.entity_layer.get_children():
		if node is WorldEnvironment2D: node.hide()
	session.world.camera.target = null
	session.world.camera.snap(Vector2(650,530))
	for index in 3:
		var direction: Vector2 = [Vector2.RIGHT,Vector2.DOWN,Vector2.UP][index]
		var actor: Actor = session.party.active_actors[0] if index==0 else session.world.spawn_actor("species.solstice",Factions.Team.COMPANION,Vector2.ZERO)
		actor.presentation.show()
		actor.position = Vector2(350+280*index,590)
		actor.set_physics_process(false)
		actor.last_direction = direction
		actor.presentation.creature_animation.previous_position = actor.position
		actor.presentation.tick(0)
		subjects.append(actor)
		var target: Actor = session.world.spawn_actor("species.briar",Factions.Team.WILD,actor.position+direction*100)
		target.set_physics_process(false)
		target.presentation.hide()
		target.health.immortal = true
		targets.append(target)
		var original: Actor = session.world.spawn_actor("species.cinder",Factions.Team.COMPANION,Vector2(350+280*index,380))
		original.set_physics_process(false)
		original.last_direction = direction
		original.presentation.tick(0)

func _physics_process(delta: float) -> void:
	frame += 1
	if frame==15: capture.call_deferred("solstice-party-before")
	if frame==30:
		var world: GameWorld = session.world
		var actor: Actor = session.party.active_actors[0]
		var position := actor.position
		for button in session.hud.panel.find_children("","Button",true,false):
			if button.text=="Эволюция":
				button.pressed.emit()
				break
		preserved = session.world==world and session.party.active_actors[0]==actor and actor.position==position and actor.species.id==&"species.solstice"
	if frame==45: capture.call_deferred("solstice-party-after")
	if frame==60: build_stage()
	if frame<60: return
	caption.text = "Уголёк → Солнцехвост · профиль / спереди / со спины\nШесть поз шага · крупный игровой пиксель"
	if frame>=210: caption.text = "Уголёк → Солнцехвост · замах и выпуск атаки"
	if frame>=265: caption.text = "Попадание → движение во время атаки: шаги продолжаются"
	if frame>=420: caption.text = "Падение · тело остаётся на земле"
	for index in subjects.size():
		var actor := subjects[index]
		var direction: Vector2 = [Vector2.RIGHT,Vector2.DOWN,Vector2.UP][index]
		actor.combat.tick(delta)
		actor.abilities.tick(delta)
		actor.velocity = Vector2.ZERO
		if frame<200 or (frame>=280 and frame<400):
			actor.velocity = direction*100
			actor.last_direction = direction
			actor.position += actor.velocity*delta
			# Return between complete cycles without counting the return as a step.
			if frame in [130,340]:
				actor.position = Vector2(350+280*index,590)
				actor.presentation.creature_animation.previous_position = actor.position
		if frame in [210,280,320]:
			targets[index].position = actor.position+direction*100
			actor.abilities.cooldowns.reset()
			actor.abilities.cast("ability.spark",targets[index])
		if frame==265: actor.presentation.hit()
		if frame==420: actor.health.damage(1000000)
		actor.presentation.tick(delta)
		var animation := actor.presentation.creature_animation
		if not seen[index].has(animation.current_clip): seen[index][animation.current_clip] = {}
		seen[index][animation.current_clip][animation.current_frame] = true
	if frame in [75,101,218,232,266,310,430,460]: capture.call_deferred("solstice-%03d"%frame)
	if frame==492: Audio.shutdown()
	if frame==498:
		var valid := preserved
		for record in seen:
			valid = valid and record.has_all(["walk","windup","release","hurt","death"])
			if valid: valid = record.walk.size()==6 and record.windup.size()==2 and record.release.size()==2 and record.death.size()==6
		print("SOLSTICE MOTION ",JSON.stringify({"frames":seen,"in_place":preserved})," verified=",valid)
		get_tree().quit(0 if valid else 1)

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/"+name+".png")
