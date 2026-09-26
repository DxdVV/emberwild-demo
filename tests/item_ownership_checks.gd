extends RefCounted

func freeze(session) -> void:
	session.world.set_physics_process(false)
	for actor in session.world.actors: actor.set_physics_process(false)

func raw(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func item_ids(data: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key in ["inventory","stash"]:
		for item in data.get(key,{}).get("items",[]): result.append(item.id)
	for item in data.get("equipment",{}).values(): result.append(item.id)
	for creature in data.get("party",[]):
		if not creature.get("held_item",{}).is_empty(): result.append(creature.held_item.id)
	for area in data.get("world_states",{}).values():
		for drop in area.get("drops",[]): result.append(drop.item.id)
	result.sort()
	return result

func run(session, check: Callable) -> void:
	session.hud.close_panel(true)
	session.new_journey()
	session.change_area("area.haven",false)
	freeze(session)
	var haven: Dictionary = session.world.item_generator.generate("item.seed",2,1)
	session.world.drops.append({"at":Vector2(600,600),"item":haven})
	session.change_area("area.grove",false)
	freeze(session)
	var grove: Dictionary = session.world.item_generator.generate("item.seed",2,1)
	session.world.drops.append({"at":Vector2(650,600),"item":grove})
	check.call(haven.id!=grove.id,"equal seeded generation in different areas cannot reuse item identity")
	var without_id := haven.duplicate(true)
	without_id.erase("id")
	var other := grove.duplicate(true)
	other.erase("id")
	check.call(without_id==other,"area identity namespace does not change item balance or RNG rolls")
	var baseline: Dictionary = session.save_data().duplicate(true)
	check.call(SavedJourney.valid(baseline),"unique items across two saved areas pass full journey preflight")
	for kind in ["inventory","stash","held","equipment","ground","two_areas","two_held","missing_id"]:
		var invalid := baseline.duplicate(true)
		match kind:
			"inventory": invalid.inventory.items.append(invalid.inventory.items[0].duplicate(true))
			"stash": invalid.stash.items.append(invalid.inventory.items[0].duplicate(true))
			"held": invalid.party[0].held_item = invalid.inventory.items[0].duplicate(true)
			"equipment": invalid.equipment["boots"] = invalid.inventory.items[2].duplicate(true)
			"ground": invalid.world_states["area.grove"].drops[0].item = invalid.inventory.items[0].duplicate(true)
			"two_areas": invalid.world_states["area.grove"].drops[0].item = invalid.world_states["area.haven"].drops[0].item.duplicate(true)
			"two_held":
				var held: Dictionary = invalid.inventory.items.pop_front()
				invalid.party[0].held_item = held.duplicate(true)
				invalid.party[1].held_item = held.duplicate(true)
			"missing_id": invalid.inventory.items[0].erase("id")
		check.call(not SavedJourney.valid(invalid),"ownership preflight rejects duplicate or missing instance identity: "+kind)
	# Invalid primary/backup must not alter current play; write rejection preserves bytes.
	var path := "user://item-ownership.json"
	check.call(SaveStore.write(baseline,path,SavedJourney.valid),"globally unique ownership snapshot saves")
	var bytes := FileAccess.get_file_as_bytes(path)
	var duplicate := baseline.duplicate(true)
	duplicate.stash.items.append(duplicate.inventory.items[0].duplicate(true))
	check.call(not SaveStore.write(duplicate,path,SavedJourney.valid) and FileAccess.get_file_as_bytes(path)==bytes,"duplicate ownership cannot replace a valid save")
	raw("user://item-ownership-invalid.json",duplicate)
	raw("user://item-ownership-invalid.json.bak",duplicate)
	var world_id: int = session.world.get_instance_id()
	check.call(not session.load_game("user://item-ownership-invalid.json") and session.world.get_instance_id()==world_id and session.save_data()==baseline,"duplicate primary and backup leave live journey intact")
	raw(path,duplicate)
	raw(path+".bak",baseline)
	var recovered := SaveStore.read_save(path,SavedJourney.valid)
	check.call(not recovered.is_empty() and SaveStore.recovered_backup and recovered.inventory.items.size()==baseline.inventory.items.size(),"duplicate ownership primary recovers from the valid backup")
	# Legacy identical bases without IDs are distinct physical instances.
	var legacy := baseline.duplicate(true)
	legacy.save_version = 1
	legacy.inventory.items = [{"base":"item.seed"},{"base":"item.seed"}]
	legacy.stash.items = [{"base":"item.seed"}]
	var migrated := SaveStore.migrate(legacy)
	check.call(SavedJourney.valid(migrated) and migrated.inventory.items[0].id!=migrated.inventory.items[1].id and migrated.inventory.items[0].id!=migrated.stash.items[0].id,"legacy identical items receive distinct stable IDs by ownership location")
	check.call(migrated==SaveStore.migrate(legacy) and not legacy.inventory.items[0].has("id"),"legacy identity migration is deterministic and retains input ownership")
	var pack := InventoryData.new()
	var stash := InventoryData.new()
	var item: Dictionary = baseline.inventory.items[0]
	check.call(pack.add(item) and not pack.add(item) and pack.items.size()==1,"inventory rejects a second copy of the same instance")
	check.call(not pack.add({"base":"item.seed"}) and not pack.add({"id":7,"base":"item.seed"}),"runtime inventory requires a nonempty string identity")
	var notifications := [0]
	var atomic := [true]
	var changed := func():
		notifications[0] += 1
		atomic[0] = atomic[0] and pack.items.size()+stash.items.size()==1
	pack.changed.connect(changed)
	stash.changed.connect(changed)
	check.call(not pack.transfer(0,pack) and notifications[0]==0,"self-transfer is a no-op without notification")
	check.call(pack.transfer(0,stash) and atomic[0] and notifications[0]==2 and stash.items[0]==item,"transfer observers see exactly one owner and unchanged instance data")
	check.call(stash.transfer(0,pack) and atomic[0] and pack.items[0]==item,"round-trip stash transfer preserves ownership and affixes")
	stash.add(item)
	var before_pack := pack.to_dict()
	var before_stash := stash.to_dict()
	check.call(not pack.transfer(0,stash) and pack.to_dict()==before_pack and stash.to_dict()==before_stash,"destination identity conflict rejects transfer without removing either item")
	pack.changed.disconnect(changed)
	stash.changed.disconnect(changed)
	# Snapshot RNG resumes the next complete instance, including ID and affixes.
	var expected: Dictionary = session.world.item_generator.generate("item.prism",3)
	check.call(SaveStore.write(baseline,path,SavedJourney.valid) and session.load_game(path),"ownership snapshot reloads for RNG continuation")
	freeze(session)
	check.call(session.world.item_generator.generate("item.prism",3)==expected,"load resumes the exact next item identity and affix sequence")
	var expected_ids := item_ids(session.save_data())
	var equipment_atomic := [true]
	var equipment_notifications := [0]
	var observe_equipment := func():
		var data: Dictionary = session.save_data()
		equipment_notifications[0] += 1
		equipment_atomic[0] = equipment_atomic[0] and SavedJourney.valid(data) and item_ids(data)==expected_ids
	session.inventory.changed.connect(observe_equipment)
	session.equip(0,0)
	check.call(session.unequip_held(0),"held item can return to inventory after equipment exchange")
	var boots: int = session.inventory.items.map(func(entry): return entry.base).find("item.boots")
	session.equip(boots)
	check.call(session.unequip_trainer("boots"),"trainer item can return to inventory after equipment exchange")
	check.call(equipment_atomic[0] and equipment_notifications[0]==4,"equipment observers see every item exactly once throughout equip and unequip")
	# Picking up a world representation must remove it before observers can save.
	session.world.trainer.position = session.world.drops[0].at
	session.world.reveal_loot = true
	session.world.interact()
	check.call(equipment_atomic[0] and equipment_notifications[0]==5 and session.world.drops.is_empty(),"pickup removes the ground owner before notifying inventory observers")
	session.inventory.changed.disconnect(observe_equipment)
	var exchanged := InventoryData.new()
	exchanged.capacity = 1
	exchanged.add(baseline.inventory.items[0])
	var returning: Dictionary = baseline.inventory.items[1]
	check.call(exchanged.exchange(0,returning)==baseline.inventory.items[0] and exchanged.items.size()==1 and exchanged.items[0]==returning,"full inventory can exchange equipment without losing either instance")
	var exchange_before := exchanged.to_dict()
	check.call(exchanged.exchange(0,returning).is_empty() and exchanged.to_dict()==exchange_before,"conflicting exchange leaves inventory unchanged")
	session.new_journey()
	session.change_area("area.haven",false)
	freeze(session)
