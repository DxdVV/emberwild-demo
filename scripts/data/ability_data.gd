class_name AbilityData extends Resource

@export var id: StringName
@export var name_key: String
@export var element: StringName = &"neutral"
@export_enum("projectile","cone","nova") var delivery: String = "projectile"
@export_range(1,360) var cone_angle: float = 75.0
@export var power: float = 1.0
@export var cooldown: float = 1.0
@export var windup: float = 0.2
@export var recovery: float = 0.2
@export var reach: float = 220.0
@export var radius: float = 0.0
@export var projectile_speed: float = 340.0
@export var cost: float = 0.0
@export var charges: int = 1
@export var effects: Array[Dictionary] = []
@export var color: Color = Color.WHITE
@export var tags: Array[String] = []
@export var audio_profile: AbilityAudioData
