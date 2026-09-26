class_name ContentFields extends RefCounted

const KINDS: Array[String] = ["species","abilities","statuses","items","areas","animations","traits"]
const STATS := ["health","attack","defense","speed","critical_chance","energy_regeneration","status_duration","cooldown_reduction"]

static func accepts(kind: String, entry) -> bool:
	match kind:
		"species": return entry is SpeciesData
		"abilities": return entry is AbilityData
		"statuses": return entry is StatusData
		"items": return entry is ItemData
		"areas": return entry is AreaData
		"animations": return entry is SpriteAnimationData
		"traits": return entry is TraitData
	return false

static func registry(registry) -> PackedStringArray:
	var errors := PackedStringArray()
	if not registry.rules is RulesData: errors.append("res://resources/rules.tres: missing RulesData")
	for kind in KINDS:
		for key in registry.get(kind):
			var entry = registry.get(kind)[key]
			if not accepts(kind,entry):
				errors.append(kind+"["+str(key)+"]: wrong Resource type")
				continue
			if str(entry.id).is_empty() or str(entry.id)!=str(key): errors.append(entry.resource_path+" / id: empty or different from registry key "+str(key))
	return errors

static func range_error(errors: PackedStringArray, value, minimum: float, maximum: float, at: String) -> void:
	if not CombatSaveSchema.number(value,minimum,maximum): errors.append(at+": expected finite number in [%s, %s]"%[minimum,maximum])

static func stats(errors: PackedStringArray, values: Dictionary, at: String, required: bool = false) -> void:
	if required:
		for key in ["health","attack","defense","speed"]:
			if not values.has(key): errors.append(at+"."+key+": missing base stat")
	for key in values:
		if key not in STATS: errors.append(at+"."+str(key)+": unknown stat")
		range_error(errors,values[key],.001 if required and key=="health" else 0,1 if key=="critical_chance" else 1000000,at+"."+str(key))

static func resources(registry) -> PackedStringArray:
	var errors := PackedStringArray()
	var elements: Array = registry.rules.type_chart.keys()
	elements.append("neutral")
	for kind in KINDS:
		for entry in registry.get(kind).values():
			var at := "%s [%s]"%[entry.resource_path,entry.id]
			if kind in ["species","abilities","statuses"] and str(entry.element) not in elements: errors.append(at+" / element: undeclared type-chart element "+str(entry.element))
			match kind:
				"species":
					stats(errors,entry.base_stats,at+" / base_stats",true)
					if not str(entry.secondary_type).is_empty() and str(entry.secondary_type) not in elements: errors.append(at+" / secondary_type: undeclared type-chart element")
					if str(entry.ai_profile) not in ["ranged","tank","support","boss"]: errors.append(at+" / ai_profile: unknown profile")
					range_error(errors,entry.visual_height,.001,10000,at+" / visual_height")
					range_error(errors,entry.capture_rate,0,1,at+" / capture_rate")
					range_error(errors,entry.evolution_level,1,100,at+" / evolution_level")
				"abilities":
					for field in ["power","cost","radius","windup","recovery"]: range_error(errors,entry.get(field),0,1000000,at+" / "+field)
					range_error(errors,entry.reach,.001,1000000,at+" / reach")
					range_error(errors,entry.cooldown,.001,3600,at+" / cooldown")
					range_error(errors,entry.charges,1,1000,at+" / charges")
					if entry.delivery=="projectile": range_error(errors,entry.projectile_speed,.001,1000000,at+" / projectile_speed")
					if entry.delivery=="cone": range_error(errors,entry.cone_angle,.001,360,at+" / cone_angle")
				"statuses":
					for field in ["duration","tick_interval"]: range_error(errors,entry.get(field),.001,StatusData.MAX_DURATION,at+" / "+field)
					range_error(errors,entry.max_stacks,1,1000,at+" / max_stacks")
					range_error(errors,entry.tick_power,0,1000000,at+" / tick_power")
					errors.append_array(ContentValidator.modifiers(entry.modifiers,at+" / modifiers"))
				"items":
					range_error(errors,entry.rarity,0,3,at+" / rarity")
					range_error(errors,entry.value,0,1000000,at+" / value")
					if str(entry.category) not in ["held","trainer"] or str(entry.slot).is_empty() or (entry.category==&"held" and entry.slot!=&"held"): errors.append(at+" / category/slot: invalid equipment category or empty slot")
				"traits":
					if entry.category not in [&"individual",&"species"]: errors.append(at+" / category: expected individual or species")
	return errors
