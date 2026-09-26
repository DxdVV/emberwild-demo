class_name CaptureSystem extends RefCounted

var rng := RandomNumberGenerator.new()

func chance(target) -> float:
	if not is_instance_valid(target) or target.species == null or target.health.current <= 0 or target.faction == Factions.Team.BOSS: return 0
	var weakness: float = 1.0-target.health.current/target.health.maximum
	return clampf(target.species.capture_rate*(0.2+0.8*weakness)+minf(0.18,target.statuses.entries.size()*0.06),0.02,0.96)

func attempt(target, inventory: InventoryData, party_full: bool) -> Dictionary:
	var probability := chance(target)
	if party_full or inventory.seals <= 0 or probability <= 0: return {"success":false,"consumed":false,"chance":probability}
	inventory.seals -= 1
	inventory.changed.emit()
	return {"success":rng.randf()<probability,"consumed":true,"chance":probability}
