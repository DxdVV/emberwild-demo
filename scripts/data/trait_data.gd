class_name TraitData extends Resource

@export var id: StringName
@export var name_key: String
@export var description_key: String
@export var category: StringName = &"individual"
@export var modifiers: Array[Dictionary] = []
@export var triggers: Array[Dictionary] = []
@export var ability_mods: Dictionary = {}
