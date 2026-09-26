class_name StatusData extends Resource

const MAX_DURATION := 3600.0

@export var id: StringName
@export var name_key: String
@export var duration: float = 4.0
@export var max_stacks: int = 1
@export var refresh: bool = true
@export var tick_interval: float = 1.0
@export var tick_power: float = 0.0
@export var element: StringName = &"neutral"
@export var modifiers: Array[Dictionary] = []
@export var color: Color = Color.WHITE
@export var icon_rows: Array[String] = []
