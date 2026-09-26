class_name LootFilter extends RefCounted

var minimum_rarity: int = 0
var categories: Dictionary = {"held":true,"trainer":true}
var always_unique: bool = true

func accepts(item: Dictionary) -> bool:
	var definition: ItemData = Database.items.get(item.get("base",""))
	if definition==null: return true
	var rarity := int(item.get("rarity",definition.rarity))
	if always_unique and rarity>=3: return true
	return rarity>=minimum_rarity and bool(categories.get(str(definition.category),true))

func to_dict() -> Dictionary:
	return {"minimum_rarity":minimum_rarity,"categories":categories.duplicate(),"always_unique":always_unique}

func restore(data) -> void:
	minimum_rarity = 0
	categories = {"held":true,"trainer":true}
	always_unique = true
	if not data is Dictionary: return
	if CombatSaveSchema.integer(data.get("minimum_rarity"),0,3): minimum_rarity = int(data.minimum_rarity)
	if data.get("always_unique") is bool: always_unique = data.always_unique
	if data.get("categories") is Dictionary:
		for category in categories:
			if data.categories.get(category) is bool: categories[category] = data.categories[category]
