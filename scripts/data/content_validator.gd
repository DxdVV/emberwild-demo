class_name ContentValidator extends RefCounted

static func validate(registry) -> PackedStringArray:
	var errors := ContentFields.registry(registry)
	if not errors.is_empty(): return errors
	errors.append_array(ContentFields.resources(registry))
	errors.append_array(RuleValidator.validate(registry))
	errors.append_array(loot_tables(registry))
	for status: StatusData in registry.statuses.values():
		if status.icon_rows.size()!=7 or status.icon_rows.any(func(row): return row.length()!=7 or not row.replace("0","").replace("1","").is_empty()):
			errors.append("Invalid 7x7 status icon: "+str(status.id))
	for id in registry.rules.default_traits:
		if not registry.traits.has(id) or registry.traits[id].category!=&"individual": errors.append("Invalid default trait: "+id)
	for species: SpeciesData in registry.species.values():
		if species.abilities.size()<2: errors.append("Missing basic/command slots: "+str(species.id))
		for id in species.trait_pool+species.passives:
			if not registry.traits.has(id): errors.append("Unknown trait: "+id+" in "+str(species.id))
		for unlock in species.ability_unlocks:
			if not registry.abilities.has(unlock.get("ability")) or not CombatSaveSchema.integer(unlock.get("level"),1,100): errors.append("Invalid ability unlock: "+str(species.id))
	for ability: AbilityData in registry.abilities.values():
		if ability.audio_profile!=null: errors.append_array(ability.audio_profile.validate())
		if ability.delivery not in ["projectile","cone","nova"] or ability.reach<=0 or ability.cooldown<=0 or ability.cost<0 or ability.charges<1: errors.append("Invalid ability parameters: "+str(ability.id))
		if ability.delivery=="nova" and (ability.radius<=0 or ability.reach!=ability.radius): errors.append("Nova targeting must match its radius: "+str(ability.id))
		if ability.delivery=="cone" and (ability.cone_angle<=0 or ability.cone_angle>360): errors.append("Invalid cone: "+str(ability.id))
		for effect in ability.effects:
			if effect.get("kind") not in ["status","knockback"]: errors.append("Unknown ability effect: "+str(ability.id))
			if effect.get("kind")=="status":
				if not registry.statuses.has(effect.get("id")): errors.append("Unknown ability status: "+str(ability.id))
				if not CombatSaveSchema.number(effect.get("duration_bonus",0),0,3600): errors.append("Invalid status duration bonus: "+str(ability.id))
			if effect.get("kind")=="knockback" and not CombatSaveSchema.number(effect.get("force",100),0,10000): errors.append("Invalid knockback force: "+str(ability.id))
	for entry in registry.traits.values()+registry.items.values():
		var id: String = str(entry.id)
		errors.append_array(modifiers(entry.modifiers,id))
		errors.append_array(triggers(entry.triggers,id,registry))
		for key in entry.ability_mods:
			if key not in ["projectiles","chains"] or not CombatSaveSchema.integer(entry.ability_mods[key],0,5): errors.append("Invalid ability modifier: "+id)
	return errors

static func loot_tables(registry) -> PackedStringArray:
	var errors := PackedStringArray()
	for required in ["common","elite","boss"]:
		if not registry.rules.loot_tables.has(required): errors.append("Missing loot table: "+required)
	for id in registry.rules.loot_tables:
		var table: Variant = registry.rules.loot_tables[id]
		if not table is Dictionary:
			errors.append("Invalid loot table: "+str(id))
			continue
		var chance: Variant = table.get("chance")
		if not (chance is int or chance is float) or not is_finite(float(chance)) or float(chance)<0 or float(chance)>1: errors.append("Invalid drop chance: "+str(id))
		var entries: Variant = table.get("entries")
		if not entries is Array or entries.is_empty():
			errors.append("Empty loot table: "+str(id))
			continue
		var seen: Dictionary = {}
		for entry in entries:
			if not entry is Dictionary:
				errors.append("Invalid loot entry: "+str(id))
				continue
			var item: String = str(entry.get("item",""))
			if not registry.items.has(item) or seen.has(item): errors.append("Unknown/duplicate loot item: "+str(id)+" / "+item)
			seen[item] = true
			var weight: Variant = entry.get("weight")
			if not (weight is int or weight is float) or not is_finite(float(weight)) or float(weight)<=0 or float(weight)>1000000: errors.append("Invalid loot weight: "+str(id))
			if entry.has("level") and not CombatSaveSchema.integer(entry.level,1,100): errors.append("Invalid loot level: "+str(id))
			if entry.has("rarity") and not CombatSaveSchema.integer(entry.rarity,-1,3): errors.append("Invalid loot rarity: "+str(id))
	return errors

static func modifiers(values, id: String) -> PackedStringArray:
	var errors := PackedStringArray()
	if not values is Array: return PackedStringArray([id+": expected modifier array"])
	for index in values.size():
		var value = values[index]
		if not value is Dictionary:
			errors.append(id+"["+str(index)+"]: expected modifier dictionary")
			continue
		if value.get("stat") not in ["health","attack","defense","speed","critical_chance","energy_regeneration","status_duration","cooldown_reduction"] or value.get("op") not in ["flat","add","multiply","override"] or not CombatSaveSchema.number(value.get("value"),-1000000,1000000): errors.append("Invalid stat modifier: "+id)
	return errors

static func triggers(values, id: String, registry) -> PackedStringArray:
	var errors := PackedStringArray()
	if not values is Array: return PackedStringArray([id+": expected trigger array"])
	for index in values.size():
		var rule = values[index]
		if not rule is Dictionary:
			errors.append(id+"["+str(index)+"]: expected trigger dictionary")
			continue
		if rule.get("event") not in ["hit","critical","kill","damage_taken","swap","summon","dodge","ability_cast"] or rule.get("effect") not in ["heal","shield","energy","status","ability"]: errors.append("Invalid trigger: "+id)
		if not CombatSaveSchema.number(rule.get("cooldown",.3),.001,3600): errors.append("Invalid trigger cooldown: "+id)
		if rule.get("effect") in ["heal","shield","energy"] and not CombatSaveSchema.number(rule.get("amount")): errors.append("Invalid trigger amount: "+id)
		if rule.get("effect")=="ability" and not registry.abilities.has(rule.get("ability")): errors.append("Unknown trigger ability: "+id)
		if rule.get("effect")=="status" and not registry.statuses.has(rule.get("status")): errors.append("Unknown trigger status: "+id)
		var conditions = rule.get("conditions",{})
		if not conditions is Dictionary:
			errors.append("Invalid trigger conditions: "+id)
			continue
		for key in conditions:
			if key in ["target_status","owner_status"]:
				if not registry.statuses.has(conditions[key]): errors.append("Unknown condition status: "+id)
			elif key=="health_below":
				if not CombatSaveSchema.number(conditions[key],0,1): errors.append("Invalid health threshold: "+id)
			else: errors.append("Unknown condition: "+id)
	return errors
