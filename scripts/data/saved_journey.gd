class_name SavedJourney extends RefCounted

# Runs after structural validation, before any live session state is replaced.
static func valid(data: Dictionary) -> bool:
	var party: Array = data.get("party",[])
	if party.is_empty() or party.size()>Database.rules.party_limit: return false
	var ids: Dictionary = {}
	var item_ids: Dictionary = {}
	for creature in party:
		var id: String = creature.get("id","")
		if id.is_empty() or ids.has(id) or not Database.species.has(creature.get("species","")): return false
		ids[id] = true
		var held: Dictionary = creature.get("held_item",{})
		if not held.is_empty() and (not claim_item(held,item_ids) or Database.items[held.base].category!=&"held"): return false
	var active: Array = data.get("active",[0])
	if active.size()>Database.rules.active_limit: return false
	var selected: Dictionary = {}
	for index in active:
		if index<0 or index>=party.size() or selected.has(index): return false
		selected[index] = true
	for id in data.get("party_state",{}).get("placements",{}):
		if not active.any(func(index): return party[index].id==id): return false
	if not Database.areas.has(data.get("area","area.haven")): return false
	for flag in data.get("quest",{}).values():
		if not flag is bool: return false
	for key in ["inventory","stash"]:
		for item in data.get(key,{}).get("items",[]):
			if not claim_item(item,item_ids): return false
	for slot in data.get("equipment",{}):
		var item: Dictionary = data.equipment[slot]
		if not claim_item(item,item_ids): return false
		var definition: ItemData = Database.items[item.base]
		if definition.category!=&"trainer" or str(definition.slot)!=slot: return false
	for snapshot in data.get("world_states",{}).values():
		for drop in snapshot.get("drops",[]):
			if not claim_item(drop.item,item_ids): return false
	return true

static func known_item(item: Dictionary) -> bool:
	return not item.is_empty() and Database.items.has(item.get("base",""))

static func claim_item(item: Dictionary, seen: Dictionary) -> bool:
	if not known_item(item) or not item.get("id") is String: return false
	var id: String = item.id
	if id.is_empty() or seen.has(id): return false
	seen[id] = true
	return true
