extends RefCounted

func raw(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func run(session, check: Callable) -> void:
	var hud: GameHUD = session.hud
	hud.close_panel(true)
	session.new_journey()
	session.change_area("area.haven",false)
	hud.show_pause()
	var baseline: Dictionary = session.save_data()
	var before_world: int = session.world.get_instance_id()
	check.call(SavedJourney.valid(baseline),"complete current journey passes content preflight")
	var item: Dictionary = baseline.inventory.items[0]
	for field in [{"rarity":"rare"},{"rarity":4},{"rarity":1.5},{"level":0},{"id":12},{"affixes":[{"modifiers":[{"stat":"attack","op":"execute","value":2}]}]},{"affixes":[{"modifiers":[{"stat":"missing","value":2}]}]}]:
		var invalid := item.duplicate(true)
		invalid.merge(field,true)
		check.call(not SaveStore.valid_item(invalid),"reject invalid item metadata before applying stats: "+str(field))
	for kind in ["unknown_species","duplicate_identity","shifted_slot","duplicate_slot","unknown_item","wrong_equipment","wrong_held","empty_drop","quest_type"]:
		var invalid := baseline.duplicate(true)
		match kind:
			"unknown_species": invalid.party[0].species = "species.removed"
			"duplicate_identity": invalid.party[1].id = invalid.party[0].id
			"shifted_slot": invalid.active = [0,8]
			"duplicate_slot": invalid.active = [1,1]
			"unknown_item": invalid.inventory.items[0].base = "item.removed"
			"wrong_equipment": invalid.equipment["boots"] = item.duplicate(true)
			"wrong_held": invalid.party[0].held_item = ItemGenerator.new().generate("item.boots")
			"empty_drop": invalid.world_states["area.haven"].drops = [{"position":[0,0],"item":{}}]
			"quest_type": invalid.quest.capture = "false"
		raw("user://invalid-journey-preflight.json",invalid)
		check.call(not session.load_game("user://invalid-journey-preflight.json") and session.world.get_instance_id()==before_world and session.save_data()==baseline,"failed load preserves all live state: "+kind)
	check.call(hud.panel_notice.visible and not hud.panel_notice.text.is_empty(),"load errors are visible inside the paused menu")
	var deep: Dictionary = {}
	for index in 40: deep = {"child":deep}
	check.call(not SaveLimits.valid(deep),"excessive save nesting is rejected before duplication")
	check.call(not SaveLimits.valid({"history":"x".repeat(4097)}),"unbounded history text is rejected")
	var many: Array = []
	many.resize(10001)
	check.call(not SaveLimits.valid(many),"oversized collections are rejected")
	var values: Array = []
	var row: Array = []
	row.resize(10000)
	for index in 11: values.append(row)
	check.call(not SaveLimits.valid(values),"aggregate save value budget applies across nested collections")
	check.call(not SaveLimits.valid({"history":NAN}),"nonfinite values in arbitrary history are rejected")
	check.call(SaveStore.valid_rng("-9223372036854775808") and SaveStore.valid_rng("9223372036854775807") and not SaveStore.valid_rng("9223372036854775808") and not SaveStore.valid_rng("-9223372036854775809"),"RNG state accepts signed 64-bit boundaries and rejects overflow")
	var path := "user://save-hardening.json"
	check.call(SaveStore.write(baseline,path,SavedJourney.valid),"validated journey writes through the atomic path")
	var newer := baseline.duplicate(true)
	newer.quest.capture = true
	check.call(SaveStore.write(newer,path,SavedJourney.valid),"second write creates a complete previous-generation backup")
	var backup := FileAccess.get_file_as_bytes(path+".bak")
	var oversized := FileAccess.open(path,FileAccess.WRITE)
	oversized.seek(SaveLimits.MAX_BYTES)
	oversized.store_8(0)
	oversized.close()
	var recovered := SaveStore.read_save(path,SavedJourney.valid)
	check.call(not recovered.is_empty() and not recovered.quest.capture and SaveStore.recovered_backup and SaveStore.last_error.is_empty(),"oversized primary falls back before JSON parsing and clears stale error state")
	check.call(SaveStore.write(newer,path,SavedJourney.valid) and FileAccess.get_file_as_bytes(path+".bak")==backup,"saving after recovery preserves the last valid backup instead of copying corrupt bytes")
	var invalid_content := baseline.duplicate(true)
	invalid_content.party[0].species = "species.removed"
	raw(path,invalid_content)
	check.call(not SaveStore.read_save(path,SavedJourney.valid).is_empty() and SaveStore.recovered_backup,"content-incompatible primary can recover from a compatible backup")
	check.call(SaveStore.write(newer,path,SavedJourney.valid) and FileAccess.get_file_as_bytes(path+".bak")==backup,"content-incompatible primary cannot replace the valid backup during repair")
	var primary_bytes := FileAccess.get_file_as_bytes(path)
	DirAccess.make_dir_absolute(path+".tmp")
	check.call(not SaveStore.write(baseline,path,SavedJourney.valid) and FileAccess.get_file_as_bytes(path)==primary_bytes and FileAccess.get_file_as_bytes(path+".bak")==backup,"temporary-file failure leaves both primary and backup bytes unchanged")
	DirAccess.remove_absolute(path+".tmp")
	var legacy := {"save_version":1,"party":[{"id":"old-creature","species":"species.cinder"}],"inventory":{"items":[{"base":"item.prism"}]}}
	var migrated := SaveStore.migrate(legacy)
	var restored: Dictionary = migrated.inventory.items[0]
	check.call(restored.rarity==Database.items["item.prism"].rarity and restored.level==1 and restored.affixes==[] and restored.id.begins_with("legacy-") and restored==SaveStore.migrate(legacy).inventory.items[0],"legacy item defaults and generated identity are deterministic without mutating input")
	check.call(not legacy.inventory.items[0].has("id") and SavedJourney.valid(migrated),"migration retains input ownership and a loadable legacy party")
	var previous_path: String = SaveStore.storage_path
	SaveStore.storage_path = "user://missing-save-directory/journey.json"
	check.call(not session.request_exit() and session.world.get_instance_id()==before_world and session.get_tree().paused and hud.panel_notice.visible,"failed save-and-quit keeps the game alive, paused, and visibly reports the problem")
	SaveStore.storage_path = path
	check.call(session.save_game() and hud.panel_notice.text==tr("notice.saved"),"retry after write failure saves the same journey and reports success in the menu")
	SaveStore.storage_path = previous_path
	hud.close_panel(true)
