class_name ItemData extends Resource

@export var id: StringName
@export var name_key: String
@export var description_key: String
@export var category: StringName = &"held"
@export var slot: StringName = &"held"
@export var rarity: int = 0
@export var modifiers: Array[Dictionary] = []
@export var ability_mods: Dictionary = {}
@export var triggers: Array[Dictionary] = []
@export var value: int = 10
