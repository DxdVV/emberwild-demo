extends Node

const VERSION := 3
const PATH := "user://journey.json"
var storage_path: String = PATH
var last_error: String = ""
var recovered_backup: bool = false

func write(data: Dictionary, path: String = "", validator: Callable = Callable()) -> bool:
	if path.is_empty(): path = storage_path
	last_error = ""
	if not validate_shape(data):
		last_error = tr("save.invalid_structure")
		return false
	if validator.is_valid() and not validator.call(data):
		last_error = tr("save.invalid_journey")
		return false
	var payload := data.duplicate(true)
	payload["save_version"] = VERSION
	var bytes := JSON.stringify(payload,"\t").to_utf8_buffer()
	if bytes.size()>SaveLimits.MAX_BYTES:
		last_error = tr("save.too_large")
		return false
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null:
		last_error = tr("save.write_failed")%FileAccess.get_open_error()
		return false
	file.store_buffer(bytes)
	file.flush()
	var write_error := file.get_error()
	var complete := file.get_length()==bytes.size()
	file.close()
	if write_error!=OK or not complete:
		last_error = tr("save.write_failed")%write_error
		return false
	# Never rotate a corrupt primary over the last valid recovery copy.
	var primary := read_file(path) if FileAccess.file_exists(path) else {}
	if not primary.is_empty() and validator.is_valid() and not validator.call(primary): primary = {}
	last_error = ""
	if not primary.is_empty():
		var backup_error := DirAccess.copy_absolute(path,path+".bak.tmp")
		if backup_error==OK: backup_error = DirAccess.rename_absolute(path+".bak.tmp",path+".bak")
		if backup_error != OK:
			last_error = tr("save.backup_failed")%backup_error
			return false
	var error := DirAccess.rename_absolute(path+".tmp",path)
	if error != OK: last_error = tr("save.commit_failed")%error
	return error == OK

func read_save(path: String = "", validator: Callable = Callable()) -> Dictionary:
	if path.is_empty(): path = storage_path
	last_error = ""
	recovered_backup = false
	var result := read_file(path)
	if not result.is_empty() and validator.is_valid() and not validator.call(result):
		result = {}
		last_error = tr("save.invalid_journey")
	if result.is_empty() and FileAccess.file_exists(path+".bak"):
		result = read_file(path+".bak")
		if not result.is_empty() and validator.is_valid() and not validator.call(result):
			result = {}
			last_error = tr("save.invalid_journey")
		recovered_backup = not result.is_empty()
	if not result.is_empty(): last_error = ""
	return result

func read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null:
		last_error = tr("save.read_failed")%FileAccess.get_open_error()
		return {}
	if file.get_length()>SaveLimits.MAX_BYTES:
		file.close()
		last_error = tr("save.too_large")
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		last_error = tr("save.invalid_json")%path
		return {}
	return migrate(json.data)

func migrate(data: Dictionary) -> Dictionary:
	if not SaveLimits.valid(data):
		last_error = tr("save.invalid_structure")
		return {}
	if not CombatSaveSchema.integer(data.get("save_version",1),1,1000000):
		last_error = tr("save.invalid_version")
		return {}
	var version := int(data.get("save_version",1))
	if version > VERSION or version < 1:
		last_error = tr("save.unsupported_version")%version
		return {}
	var result := data.duplicate(true)
	if version == 1:
		result["stash"] = result.get("stash",{})
	# v2 had no combat payload; missing states retain the legacy health ratio.
	result["save_version"] = VERSION
	if not validate_shape(result):
		last_error = tr("save.invalid_structure")
		return {}
	normalize_items(result)
	return result

func validate_shape(data: Dictionary) -> bool:
	if not SaveLimits.valid(data): return false
	if not data.get("party",[]) is Array or not data.get("active",[]) is Array: return false
	for key in ["inventory","stash","equipment","quest","trainer","world_states","party_state"]:
		if not data.get(key,{}) is Dictionary: return false
	if not CombatSaveSchema.number(data.get("party_state",{}).get("swap_remaining",0),0,60): return false
	if not CombatSaveSchema.integer(data.get("party_state",{}).get("mode",0),0,3): return false
	var placements = data.get("party_state",{}).get("placements",{})
	if not placements is Dictionary or placements.size()>Database.rules.active_limit: return false
	for id in placements:
		var placement = placements[id]
		if not id is String or id.is_empty() or id.length()>128 or not placement is Dictionary: return false
		if not valid_position(placement.get("position")) or not valid_direction(placement.get("direction")): return false
	if not data.get("area","") is String: return false
	for key in ["seed","generation"]:
		if not CombatSaveSchema.integer(data.get(key,1),0,2147483647): return false
	var trainer: Dictionary = data.get("trainer",{})
	if not CombatSaveSchema.valid(trainer.get("combat",{})) or not CombatSaveSchema.number(trainer.get("health",180)): return false
	if trainer.has("position") and not valid_position(trainer.position): return false
	if trainer.has("direction") and not valid_direction(trainer.direction): return false
	for creature in data.get("party",[]):
		if not creature is Dictionary: return false
		if not creature.get("id","") is String or not creature.get("species","") is String: return false
		if creature.get("id","").length()>128 or creature.get("species","").length()>128: return false
		if not CombatSaveSchema.valid(creature.get("combat",{})): return false
		if not CombatSaveSchema.number(creature.get("health_ratio",1),0,1): return false
		if not CombatSaveSchema.integer(creature.get("level",1),1,100) or not CombatSaveSchema.integer(creature.get("xp",0),0,1000000000000): return false
		if not CombatSaveSchema.integer(creature.get("cosmetic",0),0,1): return false
		for key in ["traits","abilities"]:
			if not creature.get(key,[]) is Array: return false
			for id in creature.get(key,[]):
				if not id is String and not id is StringName: return false
		for key in ["held_item","history"]:
			if not creature.get(key,{}) is Dictionary: return false
		if not valid_item(creature.get("held_item",{})): return false
	for key in ["inventory","stash"]:
		var container: Dictionary = data.get(key,{})
		for field in ["capacity","currency","seals","potions"]:
			if not CombatSaveSchema.integer(container.get(field,0),0,1000000000): return false
		if not container.get("items",[]) is Array: return false
		for item in container.get("items",[]):
			if not valid_item(item): return false
	for item in data.get("equipment",{}).values():
		if not valid_item(item): return false
	for index in data.get("active",[]):
		if not CombatSaveSchema.integer(index,0,1000): return false
	for snapshot in data.get("world_states",{}).values():
		if not snapshot is Dictionary: return false
		if not snapshot.get("removed",[]) is Array or not snapshot.get("enemies",{}) is Dictionary or not snapshot.get("drops",[]) is Array: return false
		for field in ["elapsed","capture_remaining"]:
			if not CombatSaveSchema.number(snapshot.get(field,0)): return false
		for field in ["damage_rng","capture_rng","loot_rng"]:
			if snapshot.has(field) and not valid_rng(snapshot[field]): return false
		for id in snapshot.get("removed",[]):
			if not id is String: return false
		for enemy in snapshot.get("enemies",{}).values():
			if not enemy is Dictionary or not valid_position(enemy.get("position")): return false
			if not CombatSaveSchema.valid(enemy.get("combat",{})) or not CombatSaveSchema.number(enemy.get("health",1)): return false
			if not CombatSaveSchema.number(enemy.get("boss_time",2),-60,3600) or not CombatSaveSchema.integer(enemy.get("boss_phase",0),0,100): return false
		for drop in snapshot.get("drops",[]):
			if not drop is Dictionary or not valid_position(drop.get("position")) or not valid_item(drop.get("item")): return false
	return true

func valid_item(item) -> bool:
	if not item is Dictionary or not item.get("base","") is String: return false
	if item.is_empty(): return true
	if str(item.get("base","")).is_empty() or not item.get("id","") is String: return false
	if item.get("base","").length()>128 or item.get("id","").length()>128: return false
	if not CombatSaveSchema.integer(item.get("rarity",0),0,3) or not CombatSaveSchema.integer(item.get("level",1),1,100): return false
	if not item.get("affixes",[]) is Array: return false
	if item.get("affixes",[]).size()>32: return false
	for affix in item.get("affixes",[]):
		if not affix is Dictionary or not affix.get("modifiers",[]) is Array: return false
		if not affix.get("id","") is String or affix.get("modifiers",[]).size()>64: return false
		for modifier in affix.get("modifiers",[]):
			if not modifier is Dictionary or not modifier.get("stat","") is String or not modifier.get("op","flat") is String: return false
			if modifier.get("stat","") not in Database.rules.stat_defaults and modifier.get("stat","") not in Database.rules.trainer_stats: return false
			if modifier.get("op","flat") not in ["flat","add","multiply","override"]: return false
			if not CombatSaveSchema.number(modifier.get("value",0),-1000000,1000000): return false
	return true

func normalize_items(data: Dictionary) -> void:
	# Early saves may omit presentation metadata; defaults are stable across reloads.
	for key in ["inventory","stash"]:
		for index in data.get(key,{}).get("items",[]).size(): normalize_item(data[key].items[index],key+":"+str(index))
	for index in data.get("party",[]).size(): normalize_item(data.party[index].get("held_item",{}),"party:"+str(index))
	for slot in data.get("equipment",{}): normalize_item(data.equipment[slot],"equipment:"+str(slot))
	for area in data.get("world_states",{}):
		for index in data.world_states[area].get("drops",[]).size(): normalize_item(data.world_states[area].drops[index].item,area+":"+str(index))

func normalize_item(item: Dictionary, location: String) -> void:
	if item.is_empty(): return
	if str(item.get("id","")).is_empty(): item.id = "legacy-"+(location+JSON.stringify(item)).sha256_text().left(24)
	if not item.has("rarity"): item.rarity = Database.items[item.base].rarity if Database.items.has(item.base) else 0
	if not item.has("level"): item.level = 1
	if not item.has("affixes"): item.affixes = []

func valid_position(position) -> bool:
	if not position is Array or position.size()!=2: return false
	return CombatSaveSchema.number(position[0],-1000000,1000000) and CombatSaveSchema.number(position[1],-1000000,1000000)

func valid_direction(direction) -> bool:
	if not valid_position(direction): return false
	var length_squared: float = Vector2(direction[0],direction[1]).length_squared()
	return length_squared>.0001 and length_squared<=1.0001

func valid_rng(value) -> bool:
	if not value is String or not value.is_valid_int() or value.begins_with("+"): return false
	var digits: String = value.trim_prefix("-")
	if digits.length()<19: return true
	if digits.length()>19: return false
	return digits<=("9223372036854775808" if value.begins_with("-") else "9223372036854775807")
