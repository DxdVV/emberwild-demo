extends Node

var session
var subjects: Array[Actor] = []
var targets: Array[Actor] = []
var seen: Array[Dictionary] = [{},{}]
var slam_hits: Array[int] = [0,0]
var aligned: bool = true
var frame: int = 0
var caption: Label
var profile_views: bool = false

func direction_at(index: int) -> Vector2:
	if profile_views: return Vector2.RIGHT if index==0 else Vector2.LEFT
	return Vector2.DOWN if index==0 else Vector2.UP

func target_at(actor: Actor, direction: Vector2) -> Vector2:
	# Keep the hit recipients below side-view silhouettes so the collapse is visible.
	return actor.position+direction*100+Vector2(0,110 if profile_views else 0)

func _ready() -> void:
	profile_views = "--profile" in OS.get_cmdline_user_args()
	session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	session.hud.close_panel()
	session.autosave_remaining = 100000
	session.hud.root.hide()
	session.world.set_physics_process(false)
	for actor in session.world.actors:
		actor.set_physics_process(false)
		actor.presentation.hide()
	session.world.trainer.position = Vector2(1400,1100)
	for node in session.world.entity_layer.get_children():
		if node is WorldEnvironment2D: node.hide()
	session.world.camera.target = null
	session.world.camera.snap(Vector2(650,540))
	for index in 2:
		var direction := direction_at(index)
		var actor: Actor = session.world.spawn_actor("species.guardian",Factions.Team.BOSS,Vector2(450+400*index,550))
		actor.set_physics_process(false)
		actor.last_direction = direction
		actor.presentation.creature_animation.tick(0)
		subjects.append(actor)
		var target: Actor = session.world.spawn_actor("species.rill",Factions.Team.COMPANION,target_at(actor,direction))
		target.set_physics_process(false)
		target.health.maximum = 2000
		target.health.current = 2000
		targets.append(target)
		actor.brain.target_ref = weakref(target)
		actor.brain.perception_remaining = 1000
	session.world.damage.resolved.connect(on_damage)
	var overlay := CanvasLayer.new()
	add_child(overlay)
	caption = UIStyle.label("",17,UIStyle.PAPER)
	caption.position = Vector2(24,22)
	caption.add_theme_color_override("font_shadow_color",Color.BLACK)
	caption.add_theme_constant_override("shadow_outline_size",4)
	overlay.add_child(caption)

func on_damage(request: Dictionary, _result: Dictionary) -> void:
	if request.ability!="ability.slam": return
	for index in subjects.size():
		if is_instance_valid(subjects[index]) and request.source_id==subjects[index].identity and request.target_id==targets[index].identity:
			slam_hits[index] += 1
			print("GUARDIAN IMPACT frame=",frame," direction=",index," pose=",subjects[index].presentation.creature_animation.current_clip," remaining=",subjects[index].brain.special_remaining)
			aligned = aligned and subjects[index].presentation.creature_animation.current_clip=="release"

func _physics_process(delta: float) -> void:
	frame += 1
	caption.text = "Страж · "+("вправо и влево" if profile_views else "спереди и со спины")+" · предупреждение → удар"
	if frame>=180: caption.text = "Третья фаза · три волны · замах остаётся направлен на метку"
	if frame>=305: caption.text = "Попадание · обычная атака · шаги"
	if frame>=420: caption.text = "Падение · шесть кадров · неподвижная опора на землю"
	for index in subjects.size():
		var actor := subjects[index]
		if not is_instance_valid(actor): continue
		var direction := direction_at(index)
		var target := targets[index]
		actor.combat.tick(delta)
		actor.abilities.tick(delta)
		actor.velocity = Vector2.ZERO
		if frame in [20,180]:
			actor.brain.boss_time = 0
			if frame==180:
				actor.health.current = actor.health.maximum*.25
				actor.brain.boss_phase = 2
		if frame==40: target.position = target_at(actor,-direction)
		if frame==60: target.position = target_at(actor,direction)
		if frame in [20,180] or actor.brain.special_remaining>0: actor.brain.tick(delta)
		if frame==310: actor.presentation.hit()
		if frame==330:
			actor.abilities.cooldowns.reset()
			actor.abilities.cast(actor.ability_id(0),target)
		if frame>=365 and frame<410:
			actor.velocity = direction*75
			actor.last_direction = direction
			actor.position += actor.velocity*delta
		if frame==420: actor.health.damage(100000)
		actor.presentation.tick(delta)
		var animation := actor.presentation.creature_animation
		if not seen[index].has(animation.current_clip): seen[index][animation.current_clip] = {}
		seen[index][animation.current_clip][animation.current_frame] = true
	if frame in [23,57,89,199,250,273,312,345,438,452,470]: capture.call_deferred()
	if frame==492: Audio.shutdown()
	if frame==498:
		var valid := aligned and slam_hits==[4,4]
		for record in seen:
			valid = valid and record.has_all(["windup","release","hurt","death"])
			if valid: valid = record.windup.size()==2 and record.release.size()==2 and record.death.size()==6
		print("GUARDIAN DIRECTIONS ",JSON.stringify({"frames":seen,"slam_hits":slam_hits,"impact_aligned":aligned})," verified=",valid)
		get_tree().quit(0 if valid else 1)

func capture() -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/%s-%03d.png"%["guardian-profile" if profile_views else "guardian-directions",frame])
