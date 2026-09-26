class_name CreatureAnimation extends RefCounted

var actor: Actor
var sprite: Sprite2D
var definition: SpriteAnimationData
var textures: Array[AtlasTexture] = []
var distance: float = 0
var time: float = 0
var previous_position: Vector2
var current_frame: int = 0
var action_textures: Array[AtlasTexture] = []
var current_clip: String = "idle"
var dead_time: float = 0
var defeated: bool = false
var facing: String = "east"
var default_cycle: Array = []
var visual_direction := Vector2.RIGHT
var previous_actor_direction := Vector2.RIGHT

func setup(owner_actor: Actor, target_sprite: Sprite2D, data: SpriteAnimationData) -> void:
	actor = owner_actor
	sprite = target_sprite
	definition = data
	previous_position = actor.global_position
	visual_direction = actor.last_direction
	previous_actor_direction = actor.last_direction
	default_cycle = range(data.frames.size())
	for frame in data.frames:
		var texture := AtlasTexture.new()
		texture.atlas = data.texture_for(frame)
		texture.region = Rect2(frame.region[0],frame.region[1],frame.region[2],frame.region[3])
		textures.append(texture)
	for frame in data.action_frames:
		var texture := AtlasTexture.new()
		texture.atlas = data.texture_for(frame,true)
		texture.region = Rect2(frame.region[0],frame.region[1],frame.region[2],frame.region[3])
		action_textures.append(texture)
	sprite.scale = Vector2.ONE*definition.render_scale
	tick(0)

func tick(delta: float, hurt: bool = false) -> void:
	var movement := actor.global_position.distance_to(previous_position)
	previous_position = actor.global_position
	time += delta
	var moving := movement>.05 and movement<maxf(8,actor.stats.value("speed")*delta*2) and actor.velocity.length_squared()>4
	if moving: distance += movement
	var direction := actor.last_direction if moving or actor.last_direction!=previous_actor_direction else visual_direction
	previous_actor_direction = actor.last_direction
	if actor.health.current<=0: direction = visual_direction
	elif actor.brain != null and actor.brain.special_remaining>0: direction = actor.brain.special_direction
	elif not moving and actor.abilities.phase!=AbilityController.Phase.IDLE and actor.abilities.target_ref!=null:
		var target = actor.abilities.target_ref.get_ref()
		if is_instance_valid(target): direction = actor.global_position.direction_to(target.global_position)
	visual_direction = direction
	if absf(direction.y)>absf(direction.x)*1.2: facing = "south" if direction.y>0 else "north"
	else: facing = "east"
	current_clip = "walk" if moving or definition.autoplay else "idle"
	var phase := 0.0
	if actor.health.current<=0:
		defeated = true
		dead_time = minf(dead_time+delta,definition.death_duration)
		current_clip = "death"
		phase = dead_time/maxf(.01,definition.death_duration)
	elif actor.brain != null and actor.brain.special_remaining>0:
		# Repeated subtraction can leave a few floating-point ulps above the
		# impact boundary, especially when later boss phases extend recovery.
		if actor.brain.special_remaining-actor.brain.special_recovery>.000001:
			current_clip = "windup"
			phase = 1-(actor.brain.special_remaining-actor.brain.special_recovery)/actor.brain.special_windup
		else:
			current_clip = "release"
			phase = 1-actor.brain.special_remaining/actor.brain.special_recovery
	elif hurt and not moving: current_clip = "hurt"
	elif not moving and actor.abilities.phase!=AbilityController.Phase.IDLE:
		if actor.abilities.phase==AbilityController.Phase.WINDUP:
			current_clip = "windup"
			phase = 1-actor.abilities.remaining/maxf(.001,actor.abilities.current.windup)
		else:
			current_clip = "release"
			phase = 1-actor.abilities.remaining/maxf(.001,actor.abilities.current.recovery)
	var clip_id := definition.clip_id(current_clip,facing)
	var action := definition.clips.has(clip_id) and not action_textures.is_empty()
	var frame: Dictionary
	if action:
		var clip: Array = definition.clips[clip_id]
		current_frame = int(clip[mini(clip.size()-1,int(clampf(phase,0,1)*clip.size()))])
		frame = definition.action_frames[current_frame]
		if sprite.texture != action_textures[current_frame]: sprite.texture = action_textures[current_frame]
	else:
		var cycle: Array = definition.directions.get(facing,default_cycle)
		var step := int(time*9) if definition.autoplay else int(distance/definition.stride_per_frame)
		current_frame = int(cycle[step%cycle.size()]) if moving or definition.autoplay else int(cycle[mini(definition.idle_frame,cycle.size()-1)])
		frame = definition.frames[current_frame]
		if sprite.texture != textures[current_frame]: sprite.texture = textures[current_frame]
	var scale_value := definition.scale_for(frame,action)
	var directional_action := action and clip_id!=current_clip
	sprite.flip_h = direction.x<0 and ((action and not directional_action) or facing=="east" or definition.directions.is_empty())
	if sprite.scale != Vector2.ONE*scale_value: sprite.scale = Vector2.ONE*scale_value
	if sprite.rotation != 0: sprite.rotation = 0
	var offset := Vector2(frame.region[2]*.5-frame.anchor[0],frame.region[3]*.5-frame.anchor[1])*scale_value
	if sprite.flip_h: offset.x = -offset.x
	var lift := definition.vertical_offset(current_clip,phase)
	var position := offset.round()+Vector2(0,roundf(lift))
	if sprite.position != position: sprite.position = position

func fall() -> void:
	if defeated: return
	defeated = true
	dead_time = 0
	tick(0)

func recover() -> void:
	defeated = false
	dead_time = 0
	previous_position = actor.global_position
	tick(0)
