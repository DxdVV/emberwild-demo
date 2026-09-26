class_name RuleValidator extends RefCounted

static func validate(registry) -> PackedStringArray:
	var errors := PackedStringArray()
	var rules: RulesData = registry.rules
	var at := "res://resources/rules.tres / "
	ContentFields.stats(errors,rules.trainer_stats,at+"trainer_stats",true)
	ContentFields.stats(errors,rules.stat_defaults,at+"stat_defaults")
	for field in ["swap_cooldown","capture_cooldown","defense_factor","level_scaling"]: ContentFields.range_error(errors,rules.get(field),0,1000000,at+field)
	for field in ["capture_range","xp_base","party_limit","active_limit"]: ContentFields.range_error(errors,rules.get(field),1,1000000,at+field)
	if rules.active_limit!=2 or rules.party_limit<rules.active_limit: errors.append(at+"active_limit/party_limit: current command UI requires two active slots within the party limit")
	var elements: Array = rules.type_chart.keys()
	elements.append("neutral")
	for element in rules.type_chart:
		if not element is String or str(element).is_empty(): errors.append(at+"type_chart: element IDs must be nonempty strings")
		var row = rules.type_chart[element]
		if not row is Dictionary:
			errors.append(at+"type_chart."+str(element)+": expected a dictionary")
			continue
		for target in row:
			if target not in elements: errors.append(at+"type_chart."+str(element)+": undeclared target element "+str(target))
			ContentFields.range_error(errors,row[target],0,100,at+"type_chart."+str(element)+"."+str(target))
	for index in rules.reactions.size():
		var reaction: Dictionary = rules.reactions[index]
		var field := at+"reactions["+str(index)+"]"
		if not registry.statuses.has(reaction.get("status")) or reaction.get("element") not in elements or reaction.get("effect") not in ["chain","bonus"]: errors.append(field+": unknown status, element or effect")
		if reaction.get("effect")=="chain" and not CombatSaveSchema.integer(reaction.get("count"),1,20): errors.append(field+".count: expected 1..20 chains")
		if reaction.get("effect")=="bonus": ContentFields.range_error(errors,reaction.get("multiplier"),0,100,field+".multiplier")
	for kind in ["elite_affixes","item_affixes"]:
		var seen := {}
		var affixes: Array = rules.get(kind)
		for index in affixes.size():
			var affix: Dictionary = affixes[index]
			var field: String = at+kind+"["+str(index)+"]"
			var id = affix.get("id")
			if not id is String or str(id).is_empty() or seen.has(id): errors.append(field+".id: missing or duplicate affix ID")
			else: seen[id] = true
			errors.append_array(ContentValidator.modifiers(affix.get("modifiers",[]),field+".modifiers"))
			errors.append_array(ContentValidator.triggers(affix.get("triggers",[]),field+".triggers",registry))
	if rules.boss_phases.is_empty(): errors.append(at+"boss_phases: at least one phase is required")
	var previous := 2.0
	for index in rules.boss_phases.size():
		var phase: Dictionary = rules.boss_phases[index]
		var field := at+"boss_phases["+str(index)+"]"
		var threshold = phase.get("threshold")
		if not CombatSaveSchema.number(threshold,0,1): errors.append(field+".threshold: expected finite health ratio")
		else:
			if float(threshold)>=previous or (index==0 and float(threshold)!=1): errors.append(field+".threshold: phases must start at 1 and descend strictly")
			previous = float(threshold)
		ContentFields.range_error(errors,phase.get("interval"),.001,3600,field+".interval")
		ContentFields.range_error(errors,phase.get("radius"),1,10000,field+".radius")
		if not CombatSaveSchema.integer(phase.get("waves"),1,100): errors.append(field+".waves: expected positive integer")
	return errors
