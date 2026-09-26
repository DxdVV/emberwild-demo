class_name ActorPresentation extends Node2D

signal defeat_finished

var actor
var sprite: Sprite2D
var animator: AnimationPlayer
var time: float = 0
var flash: float = 0
var cast_time: float = 0
var color: Color
var size: float
var character_animation: CharacterAnimation
var creature_animation: CreatureAnimation
var fall_tween: Tween
var was_focused: bool = false
var was_debug: bool = false

func _ready() -> void:
	set_process(false)
	var cell: int = actor.species.sprite_cell if actor.species != null else 0
	size = actor.species.visual_height if actor.species != null else 106
	color = actor.species.color if actor.species != null else Color("c7e5bd")
	sprite = Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/characters/creatures-pixel.png")
	atlas.region = Rect2((cell%3)*512,(cell/3)*512,512,512)
	sprite.texture = atlas
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.material = preload("res://shaders/sprite_pixels.tres")
	sprite.scale = Vector2.ONE * size/480
	sprite.position.y = -size*.47
	add_child(sprite)
	if actor.individual != null and actor.individual.cosmetic == 1: sprite.modulate = Color(1.15,.85,1.15)
	animator = AnimationPlayer.new()
	add_child(animator)
	var library := AnimationLibrary.new()
	var animation := Animation.new()
	animation.length = .24
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track,NodePath(str(sprite.name)+":rotation"))
	animation.track_insert_key(track,0,0)
	animation.track_insert_key(track,.08,-.12)
	animation.track_insert_key(track,.24,0)
	library.add_animation("cast",animation)
	animator.add_animation_library("",library)
	if actor.faction == Factions.Team.TRAINER:
		character_animation = CharacterAnimation.new()
		character_animation.setup(actor,sprite)
		character_animation.footfall.connect(play_footfall)
	elif Database.animations.has(str(actor.species.animation_id)):
		creature_animation = CreatureAnimation.new()
		creature_animation.setup(actor,sprite,Database.animations[str(actor.species.animation_id)])
	actor.health.changed.connect(refresh_health)
	actor.statuses.changed.connect(queue_redraw)

func play_footfall() -> void:
	Audio.play("footstep",actor.global_position)

func refresh_species() -> void:
	size = actor.species.visual_height
	color = actor.species.color
	var previous := creature_animation
	creature_animation = null
	if Database.animations.has(str(actor.species.animation_id)):
		creature_animation = CreatureAnimation.new()
		creature_animation.setup(actor,sprite,Database.animations[str(actor.species.animation_id)])
		if previous != null:
			creature_animation.distance = previous.distance
			creature_animation.time = previous.time
			# Evolution may use a different fall duration; keep its visual progress.
			creature_animation.dead_time = clampf(previous.dead_time/previous.definition.death_duration,0,1)*creature_animation.definition.death_duration
			creature_animation.defeated = previous.defeated
			creature_animation.visual_direction = previous.visual_direction
			creature_animation.previous_actor_direction = previous.previous_actor_direction
		creature_animation.tick(0,flash>0)
	else:
		var atlas := AtlasTexture.new()
		atlas.atlas = load("res://assets/characters/creatures-pixel.png")
		var cell: int = actor.species.sprite_cell
		atlas.region = Rect2((cell%3)*512,(cell/3)*512,512,512)
		sprite.texture = actor.species.portrait if actor.species.portrait!=null else atlas
		sprite.scale = Vector2.ONE*size/480
		sprite.position.y = -size*.47
	queue_redraw()

func refresh_health(_current: float, _maximum: float) -> void: queue_redraw()

func marker_anchor() -> Vector2:
	var frame: Dictionary = {}
	if character_animation!=null:
		var animation := character_animation
		frame = animation.definition.action_frames[animation.action_frame] if animation.action_frame>=0 else animation.definition.frames[animation.previous_frame]
	elif creature_animation!=null:
		var animation := creature_animation
		var action := animation.definition.clips.has(animation.definition.clip_id(animation.current_clip,animation.facing))
		frame = animation.definition.action_frames[animation.current_frame] if action else animation.definition.frames[animation.current_frame]
	var bounds := sprite.get_rect()
	if frame.has("visible_bounds"):
		var visible: Array = frame.visible_bounds
		bounds = Rect2(bounds.position+Vector2(visible[0],visible[1]),Vector2(visible[2],visible[3]))
	# The top comes from real opaque pixels, excluding transparent atlas padding.
	var point := bounds.position+Vector2(bounds.size.x*.5,0)
	if sprite.flip_h: point.x = -point.x
	if sprite.flip_v: point.y = -point.y
	return sprite.to_global(point)+Vector2(0,-4)

func refresh_overlay() -> void:
	var focused: bool = actor.world.focus_target==actor
	if focused!=was_focused or actor.world.debug_draw or was_debug:
		was_focused = focused
		was_debug = actor.world.debug_draw
		queue_redraw()

func tick(delta: float) -> void:
	time += delta
	flash = maxf(0,flash-delta)
	cast_time = maxf(0,cast_time-delta)
	refresh_overlay()
	if character_animation != null:
		character_animation.tick(delta,flash>0)
		sprite.self_modulate = Color(1.7,1.3,1.1) if flash>0 else Color.WHITE
		return
	if creature_animation != null:
		creature_animation.tick(delta,flash>0)
		sprite.self_modulate = Color(1.7,1.3,1.1) if flash>0 else Color.WHITE
		return
	var moving: bool = actor.velocity.length_squared()>25
	var bob := sin(time*(12 if moving else 2.6))*(2.5 if moving else .7)
	sprite.position.y = roundf(-size*.47+bob)
	sprite.flip_h = actor.last_direction.x < -.1
	sprite.self_modulate = Color(2,1.5,1.5) if flash>0 else Color.WHITE

func hit() -> void:
	flash = .1
	if character_animation!=null: character_animation.hit()

func cast(_color: Color) -> void:
	cast_time = .25
	if is_instance_valid(animator) and character_animation==null and creature_animation==null: animator.play("cast")

func fall() -> void:
	if character_animation != null:
		character_animation.fall()
		# Only the trainer's visual defeat runs through the paused defeat transition.
		# Gameplay, cooldowns and other actors remain paused.
		process_mode = Node.PROCESS_MODE_ALWAYS
		set_process(not character_animation.defeat_complete)
		return
	if creature_animation != null:
		creature_animation.fall()
		return
	if fall_tween != null and fall_tween.is_valid(): fall_tween.kill()
	fall_tween = create_tween()
	fall_tween.tween_property(sprite,"modulate:a",.25,.5)
	fall_tween.parallel().tween_property(sprite,"rotation",.6,.5)

func _process(delta: float) -> void:
	if character_animation==null: return
	tick(delta)
	if character_animation.defeat_complete:
		set_process(false)
		defeat_finished.emit()

func recover() -> void:
	set_process(false)
	process_mode = Node.PROCESS_MODE_INHERIT
	if fall_tween != null and fall_tween.is_valid(): fall_tween.kill()
	sprite.modulate.a = 1
	sprite.rotation = 0
	flash = 0
	if creature_animation != null: creature_animation.recover()
	if character_animation != null: character_animation.recover()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO,0,Vector2(1,.42))
	draw_circle(Vector2.ZERO,27 if actor.species != null else 21,Color(0,0,0,.3))
	if actor.faction in [Factions.Team.TRAINER,Factions.Team.COMPANION]:
		draw_arc(Vector2.ZERO,25,0,TAU,40,Color(color,.65),1.5)
	if actor == actor.world.focus_target:
		draw_arc(Vector2.ZERO,32,0,TAU,40,Color("ffd589"),2)
	if not actor.elite.is_empty(): draw_arc(Vector2.ZERO,34,0,TAU,40,Color("e7b75b"),2)
	draw_set_transform(Vector2.ZERO)
	if actor.health.current < actor.health.maximum and actor.health.current > 0:
		draw_rect(Rect2(-23,-size-5,46,4),Color("101c22"))
		var bar_color := Color("ff826b") if actor.faction>=Factions.Team.WILD else Color("80d7b0")
		draw_rect(Rect2(-22,-size-4,44*actor.health.current/actor.health.maximum,2),bar_color)
	var index := 0
	for entry in actor.statuses.entries.values():
		StatusGlyph.draw(self,entry.definition.icon_rows,Vector2(floorf(-actor.statuses.entries.size()*4.5)+index*9,-size-17),entry.definition.color)
		index += 1
	if actor.world.debug_draw:
		draw_arc(Vector2.ZERO,actor.body_radius,0,TAU,24,Color("65ddd0"),1)
		draw_arc(Vector2.ZERO,21,0,TAU,20,Color.MAGENTA,1)
		draw_line(Vector2.ZERO,actor.velocity*.25,Color.YELLOW)
		if actor.brain != null:
			draw_string(ThemeDB.fallback_font,Vector2(-20,20),ActorBrain.State.keys()[actor.brain.state],HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.WHITE)
			var previous := Vector2.ZERO
			for waypoint in actor.brain.route:
				var point := to_local(waypoint)
				draw_line(previous,point,Color("65ddd0"),1)
				draw_rect(Rect2(point-Vector2(2,2),Vector2(4,4)),Color("65ddd0"))
				previous = point
