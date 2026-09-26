class_name Progression extends RefCounted

static func threshold(level: int) -> int:
	return Database.rules.xp_base + level*level*15

static func award(creature: CreatureInstance, amount: int) -> bool:
	var changed := false
	creature.xp += maxi(0,amount)
	while creature.level < 100 and creature.xp >= threshold(creature.level):
		creature.xp -= threshold(creature.level)
		creature.level += 1
		changed = true
	if changed: creature.refresh_stats()
	return changed

static func evolve(creature: CreatureInstance) -> bool:
	var species: SpeciesData = Database.species.get(creature.species_id)
	if species == null or str(species.evolution_target).is_empty() or creature.level < species.evolution_level: return false
	if not Database.species.has(str(species.evolution_target)): return false
	creature.history["evolved_from"] = creature.species_id
	creature.species_id = str(species.evolution_target)
	normalize_loadout(creature)
	creature.refresh_stats()
	return true

static func available_abilities(creature: CreatureInstance) -> Array:
	var species: SpeciesData = Database.species[creature.species_id]
	var result: Array = species.abilities.duplicate()
	for unlock in species.ability_unlocks:
		if creature.level>=int(unlock.level) and Database.abilities.has(unlock.ability) and unlock.ability not in result: result.append(unlock.ability)
	return result

static func normalize_loadout(creature: CreatureInstance) -> void:
	var species: SpeciesData = Database.species[creature.species_id]
	var available := available_abilities(creature)
	var selected: String = str(creature.abilities[1]) if creature.abilities.size()>1 else ""
	if selected not in available or selected==species.abilities[0]: selected = species.abilities[1]
	creature.abilities = [species.abilities[0],selected]

static func select_command(creature: CreatureInstance, ability_id: String) -> bool:
	if ability_id not in available_abilities(creature) or ability_id==Database.species[creature.species_id].abilities[0]: return false
	normalize_loadout(creature)
	creature.abilities[1] = ability_id
	return true
