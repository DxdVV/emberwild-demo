class_name AreaData extends Resource

@export var id: StringName
@export var name_key: String
@export var subtitle_key: String
@export var size: Vector2 = Vector2(2200,1400)
@export var level_min: int = 1
@export var level_max: int = 3
@export var safe: bool = false
@export var tint: Color = Color.WHITE
@export var ground: Color = Color("263e32")
@export var layout: AreaLayout
@export var exits: Array[String] = []
@export var weather: StringName = &"motes"
