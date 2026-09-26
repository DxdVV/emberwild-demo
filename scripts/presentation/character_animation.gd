class_name CharacterAnimation extends RefCounted

signal footfall

var actor: Actor
var sprite: Sprite2D
var travelled: float = 0
var previous_position: Vector2
var previous_frame: int = -1
var idle_time: float = 0
var facing_row: int = 1
var frame_data: Array = []
var frame_textures: Array[AtlasTexture] = []
var scale_factor: float = .44
var definition: SpriteAnimationData
var action_textures: Array[AtlasTexture] = []
var action_frame: int = -1
var current_clip: String = "idle"
var dead_time: float = 0
var defeated: bool = false
var defeat_frame: int = -1
var defeat_complete: bool = false
var hurt_remaining: float = 0
var was_hurt: bool = false
const STRIDE_PER_FRAME := 17.0

func setup(owner_actor: Actor, target_sprite: Sprite2D) -> void:
	actor = owner_actor
	sprite = target_sprite
	definition = Database.animations["animation.ranger"]
	var sheet := definition.texture
	frame_data = definition.frames
	scale_factor = definition.render_scale
	for data in frame_data:
		var texture := AtlasTexture.new()
		texture.atlas = sheet
		texture.region = Rect2(data.region[0],data.region[1],data.region[2],data.region[3])
		frame_textures.append(texture)
	for data in definition.action_frames:
		var texture := AtlasTexture.new()
		texture.atlas = definition.texture_for(data,true)
		texture.region = Rect2(data.region[0],data.region[1],data.region[2],data.region[3])
		action_textures.append(texture)
	sprite.hframes = 1
	sprite.vframes = 1
	sprite.scale = Vector2.ONE*scale_factor
	previous_position = actor.global_position
	# Authored sheet frames have slightly different baselines. Metadata anchors the feet,
	# not the bounding-box center, so swinging arms/cape never shift the entire body.
	face(actor.last_direction)
	tick(0,false)

func tick(delta: float, hurt: bool) -> void:
	if hurt and not was_hurt: hit()
	was_hurt = hurt
	hurt_remaining = maxf(0,hurt_remaining-delta)
	if defeated:
		dead_time = minf(dead_time+delta,definition.death_duration)
		set_action("death",dead_time/maxf(.001,definition.death_duration))
		defeat_frame = action_frame
		defeat_complete = dead_time>=definition.death_duration
		return
	var displacement := actor.global_position-previous_position
	previous_position = actor.global_position
	# Teleports and dodges are not steps. Measure resolved movement, not input,
	# so the feet also stop when the character runs against a wall.
	var walking_distance := displacement.length()
	var previous_step := int(travelled/(STRIDE_PER_FRAME*3))
	var moving := walking_distance>.1 and walking_distance<maxf(8,actor.stats.value("speed")*delta*2) and actor.velocity.length_squared()>4
	if actor.dodge_time>0:
		face(actor.dodge_direction)
	elif moving:
		face(actor.last_direction)
	elif actor.abilities.phase!=AbilityController.Phase.IDLE and actor.abilities.target_ref!=null:
		var target = actor.abilities.target_ref.get_ref()
		if is_instance_valid(target): face(actor.global_position.direction_to(target.global_position))
	if moving:
		if actor.dodge_time<=0: travelled += walking_distance
		idle_time = 0
	else: idle_time += delta
	var frame_index := 18
	if actor.dodge_time>0:
		set_action("dodge",1-actor.dodge_time/Actor.DODGE_DURATION)
		return
	elif hurt_remaining>0 and not moving:
		set_action("hurt",1-hurt_remaining/definition.hurt_duration)
		return
	elif moving:
		# Casting never freezes the legs of a moving character. Full-body cast
		# poses belong to planted casts; the lantern/projectile carries a moving cast.
		frame_index = facing_row*6 + int(travelled/STRIDE_PER_FRAME)%6
		current_clip = "walk"
	elif actor.abilities.phase == AbilityController.Phase.WINDUP:
		set_action("windup",ability_phase())
		return
	elif actor.abilities.phase == AbilityController.Phase.RECOVERY:
		set_action("release",ability_phase())
		return
	else:
		current_clip = "idle"
		if facing_row==2: frame_index = 13
		elif facing_row==0: frame_index = 1
		else: frame_index = 18+int(idle_time*1.4)%2
	set_frame(frame_index)
	# Two grounded contacts per six-pose cycle, driven by the same resolved
	# distance as the feet. Never catch up missed sounds after a teleport/pause.
	if current_clip=="walk" and int(travelled/(STRIDE_PER_FRAME*3))>previous_step:
		footfall.emit()

func hit() -> void:
	hurt_remaining = definition.hurt_duration
	was_hurt = true

func face(direction: Vector2) -> void:
	if direction.is_zero_approx(): return
	if absf(direction.y)>absf(direction.x)*1.2: facing_row = 0 if direction.y>0 else 2
	else: facing_row = 1
	sprite.flip_h = facing_row==1 and direction.x<0

func ability_phase() -> float:
	if actor.abilities.current==null: return 0
	var duration := actor.abilities.current.windup if actor.abilities.phase==AbilityController.Phase.WINDUP else actor.abilities.current.recovery
	return 1-actor.abilities.remaining/maxf(.001,duration)

func set_action(clip: String, phase: float = 0) -> void:
	current_clip = clip
	var facing: String = ["south","east","north"][facing_row]
	var sequence: Array = definition.clips[definition.clip_id(clip,facing)]
	action_frame = int(sequence[mini(sequence.size()-1,int(clampf(phase,0,1)*sequence.size()))])
	previous_frame = -1
	sprite.texture = action_textures[action_frame]
	var frame: Dictionary = definition.action_frames[action_frame]
	place_frame(frame,definition.scale_for(frame,true))

func set_frame(index: int) -> void:
	previous_frame = index
	action_frame = -1
	if sprite.texture != frame_textures[index]: sprite.texture = frame_textures[index]
	place_frame(frame_data[index],scale_factor)

func place_frame(data: Dictionary, frame_scale: float) -> void:
	sprite.scale = Vector2.ONE*frame_scale
	var offset_x := roundf((data.region[2]*.5-data.anchor[0])*frame_scale)
	sprite.position = Vector2(-offset_x if sprite.flip_h else offset_x,-roundf((data.anchor[1]-data.region[3]*.5)*frame_scale))
	sprite.rotation = 0

func fall() -> void:
	if defeated: return
	defeated = true
	dead_time = 0
	defeat_complete = false
	tick(0,false)

func recover() -> void:
	hurt_remaining = 0
	was_hurt = false
	defeated = false
	defeat_complete = false
	defeat_frame = -1
	dead_time = 0
	travelled = 0
	idle_time = 0
	previous_position = actor.global_position
	tick(0,false)
