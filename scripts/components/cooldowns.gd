class_name CooldownComponent extends RefCounted

var timers: Dictionary = {}
var charges: Dictionary = {}
var global_remaining: float = 0

func available(ability: AbilityData) -> bool:
	return global_remaining <= 0 and int(charges.get(ability.id,ability.charges)) > 0

func use(ability: AbilityData, reduction: float = 0) -> void:
	charges[ability.id] = int(charges.get(ability.id,ability.charges))-1
	if not timers.has(ability.id): timers[ability.id] = {"remaining":duration(ability,reduction),"base":duration(ability,reduction),"max":ability.charges}
	global_remaining = 0.15

static func duration(ability: AbilityData, reduction: float = 0) -> float:
	return ability.cooldown * maxf(0.15,1-reduction)

func remaining(id: StringName) -> float:
	return float(timers.get(id,{}).get("remaining",0))

func tick(delta: float) -> void:
	global_remaining = maxf(0,global_remaining-delta)
	for id in timers.keys():
		timers[id].remaining -= delta
		while timers.has(id) and timers[id].remaining <= 0:
			charges[id] += 1
			if charges[id] >= timers[id].max: timers.erase(id)
			else: timers[id].remaining += timers[id].base

func reset() -> void:
	timers.clear()
	charges.clear()
	global_remaining = 0

func to_dict() -> Dictionary:
	var stored := charges.duplicate()
	# A fully replenished ability has no timer and uses the definition's default.
	# Omit that redundant cache, matching restore without changing live charges.
	for id in stored.keys():
		if not timers.has(id) and Database.abilities.has(id) and int(stored[id])==Database.abilities[id].charges: stored.erase(id)
	return {"timers":timers.duplicate(true),"charges":stored,"global":global_remaining}

func restore(data: Dictionary) -> void:
	reset()
	global_remaining = clampf(float(data.get("global",0)),0,60)
	for id in data.get("timers",{}):
		if not Database.abilities.has(id): continue
		var definition: AbilityData = Database.abilities[id]
		var timer: Dictionary = data.timers[id]
		var count := clampi(int(data.get("charges",{}).get(id,0)),0,definition.charges)
		if count>=definition.charges: continue
		charges[id] = count
		timers[id] = {"remaining":clampf(float(timer.remaining),0,3600),"base":clampf(float(timer.base),.001,3600),"max":definition.charges}
