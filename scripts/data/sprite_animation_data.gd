class_name SpriteAnimationData extends Resource

@export var id: StringName
@export var texture: Texture2D
@export var frames: Array[Dictionary] = []
@export var stride_per_frame: float = 15
@export var autoplay: bool = false
@export var idle_frame: int = 1
@export var render_scale: float = .4
@export var directions: Dictionary = {}
@export var action_texture: Texture2D
@export var action_frames: Array[Dictionary] = []
@export var action_scale: float = .4
@export var clips: Dictionary = {}
@export var death_duration: float = .55
@export_range(0.001,1.0) var death_ground_phase: float = 1.0
@export var directional_texture: Texture2D
@export var directional_scale: float = .4
@export var supplemental_textures: Dictionary[String,Texture2D] = {}
@export var supplemental_scales: Dictionary[String,float] = {}
@export var hurt_duration: float = .24

func texture_for(frame: Dictionary, action: bool = false) -> Texture2D:
	var source: String = frame.get("source","")
	if supplemental_textures.has(source): return supplemental_textures[source]
	if frame.get("source")=="directional": return directional_texture
	if source not in ["","default"]: return null
	return action_texture if action else texture

func scale_for(frame: Dictionary, action: bool = false) -> float:
	var source: String = frame.get("source","")
	if supplemental_textures.has(source): return supplemental_scales.get(source,0)
	if frame.get("source")=="directional": return directional_scale
	return action_scale if action else render_scale

func clip_id(clip: String, facing: String) -> String:
	var directional := clip+"."+facing
	return directional if clips.has(directional) else clip

func vertical_offset(clip: String, phase: float = 0) -> float:
	if not autoplay: return 0
	if clip=="death": return -16.0*(1-clampf(phase/maxf(.001,death_ground_phase),0,1))
	return -16.0
