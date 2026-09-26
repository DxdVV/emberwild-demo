class_name ItemGenerator extends RefCounted

var rng := RandomNumberGenerator.new()
var identity_scope: String = ""

func generate_drop(table_id: String, level: int) -> Dictionary:
	var table: Dictionary = Database.rules.loot_tables.get(table_id,{})
	var entries: Array = table.get("entries",[])
	if entries.is_empty(): return {}
	var chance: float = table.get("chance",0.0)
	if chance<=0 or (chance<1 and rng.randf()>=chance): return {}
	var total := 0.0
	for entry in entries: total += float(entry.weight)
	var roll := rng.randf()*total
	for entry in entries:
		roll -= float(entry.weight)
		if roll<0: return generate(entry.item,int(entry.get("level",level)),int(entry.get("rarity",-1)))
	# randf may include 1.0; the upper endpoint still belongs to the last item.
	var last: Dictionary = entries.back()
	return generate(last.item,int(last.get("level",level)),int(last.get("rarity",-1)))

func generate(base_id: String, level: int = 1, rarity: int = -1) -> Dictionary:
	if not Database.items.has(base_id): return {}
	var definition: ItemData = Database.items[base_id]
	if rarity < 0: rarity = maxi(definition.rarity,0 if rng.randf()<0.5 else rng.randi_range(1,2))
	var affixes: Array = []
	var pool: Array = Database.rules.item_affixes.duplicate(true)
	for index in mini(rarity,pool.size()):
		var choice := rng.randi_range(0,pool.size()-1)
		affixes.append(pool[choice])
		pool.remove_at(choice)
	var identity := "item-%x-%x" % [rng.randi(),rng.randi()]
	# Separate areas can intentionally share a seeded roll sequence. Their physical
	# items must still have separate identities, without advancing gameplay RNG.
	if not identity_scope.is_empty(): identity = identity_scope.sha256_text().left(16)+"-"+identity
	return {"id":identity,"base":base_id,"level":level,"rarity":rarity,"affixes":affixes}

static func modifiers(item: Dictionary) -> Array:
	if not Database.items.has(item.get("base","")): return []
	var result: Array = Database.items[item.base].modifiers.duplicate(true)
	for affix in item.get("affixes",[]): result.append_array(affix.get("modifiers",[]))
	return result
