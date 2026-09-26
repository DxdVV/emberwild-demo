class_name InventoryData extends RefCounted

signal changed
var capacity: int = 30
var items: Array[Dictionary] = []
var currency: int = 0
var seals: int = 12
var potions: int = 5

func can_add(item: Dictionary) -> bool:
	if items.size()>=capacity or not item.get("id") is String or item.id.is_empty(): return false
	return Database.items.has(item.get("base","")) and not items.any(func(existing): return existing.get("id")==item.id)

func add(item: Dictionary, notify: bool = true) -> bool:
	if not can_add(item): return false
	items.append(item.duplicate(true))
	if notify: changed.emit()
	return true

func take(index: int, notify: bool = true) -> Dictionary:
	if index < 0 or index >= items.size(): return {}
	var item := items[index]
	items.remove_at(index)
	if notify: changed.emit()
	return item

func exchange(index: int, returning: Dictionary, notify: bool = true) -> Dictionary:
	if index<0 or index>=items.size(): return {}
	if not returning.is_empty():
		if not returning.get("id") is String or returning.id.is_empty() or not Database.items.has(returning.get("base","")): return {}
		if items.any(func(existing): return existing.get("id")==returning.id): return {}
	var incoming := items[index]
	items.remove_at(index)
	if not returning.is_empty(): items.append(returning.duplicate(true))
	if notify: changed.emit()
	return incoming

func transfer(index: int, destination: InventoryData) -> bool:
	if destination==null or destination==self or index<0 or index>=items.size(): return false
	if not destination.can_add(items[index]): return false
	var item := items[index]
	items.remove_at(index)
	destination.items.append(item.duplicate(true))
	# Observers may save or redraw in these callbacks. Both owners must already
	# reflect the completed transfer before either notification is delivered.
	changed.emit()
	destination.changed.emit()
	return true

func to_dict() -> Dictionary:
	return {"items":items.duplicate(true),"currency":currency,"seals":seals,"potions":potions}

func restore(data: Dictionary) -> void:
	items.clear()
	for item in data.get("items",[]):
		if item is Dictionary and Database.items.has(item.get("base","")): items.append(item.duplicate(true))
	currency = maxi(0,int(data.get("currency",0)))
	seals = maxi(0,int(data.get("seals",12)))
	potions = maxi(0,int(data.get("potions",5)))
	changed.emit()
