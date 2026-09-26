class_name SpeciesData extends Resource

@export var id: StringName
@export var name_key: String
@export var element: StringName = &"neutral"
@export var secondary_type: StringName
@export var base_stats: Dictionary = {"health":100.0,"attack":12.0,"defense":5.0,"speed":100.0}
@export var abilities: Array[String] = []
@export var sprite_cell: int = 0
@export var portrait: Texture2D
@export var visual_height: float = 100.0
@export var color: Color = Color.WHITE
@export var ai_profile: StringName = &"ranged"
@export var capture_rate: float = 0.65
@export var evolution_target: StringName
@export var evolution_level: int = 8
@export var tags: Array[String] = []
@export var animation_id: StringName
@export var trait_pool: Array[String] = []
@export var passives: Array[String] = []
@export var ability_unlocks: Array[Dictionary] = []
