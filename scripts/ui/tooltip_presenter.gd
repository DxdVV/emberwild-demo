class_name TooltipPresenter extends RefCounted

static func t(key: String) -> String: return TranslationServer.translate(key)

static func ability_values(ability: AbilityData, state: CombatState, preview: StatsComponent = null) -> Dictionary:
	var damage := DamageSystem.new()
	damage.rules = Database.rules
	var stats := state.stats if preview==null else preview
	return {"damage":damage.calculate({"attack":stats.value("attack"),"power":ability.power}).final_damage,"cooldown":CooldownComponent.duration(ability,stats.value("cooldown_reduction")),"cost":ability.cost}

static func ability_text(ability: AbilityData, state: CombatState) -> String:
	var values := ability_values(ability,state)
	var lines: Array[String] = [t("tip.damage")%values.damage,t("tip.cost")%[values.cost,values.cooldown]]
	match ability.delivery:
		"cone": lines.append(t("tip.cone")%[ability.reach,ability.cone_angle])
		"nova": lines.append(t("tip.nova")%ability.radius)
		_: lines.append(t("tip.projectile")%[ability.reach,ability.radius])
	for effect in ability.effects:
		if effect.kind=="status":
			var definition: StatusData = Database.statuses[effect.id]
			lines.append(t("tip.status")%[t(definition.name_key),StatusComponent.duration_for(definition,state.stats,float(effect.get("duration_bonus",0))),definition.max_stacks])
			if definition.tick_power>0: lines.append(t("tip.dot")%(state.stats.value("attack")*definition.tick_power/maxf(.001,definition.tick_interval)))
			lines.append_array(modifier_lines(definition.modifiers))
		elif effect.kind=="knockback": lines.append(t("tip.knockback")%float(effect.get("force",100)))
	var mods := state.ability_mods()
	if mods.projectiles>1 or mods.chains>0: lines.append(t("tip.active_mods")%[mods.projectiles if ability.delivery=="projectile" else 0,mods.chains])
	return "\n".join(lines)

static func modifier_lines(modifiers: Array) -> Array[String]:
	var lines: Array[String] = []
	for modifier in modifiers:
		var amount := float(modifier.value)
		var formatted := "%+.1f"%amount
		match modifier.get("op","flat"):
			"add": formatted = "%+.0f%%"%(amount*100)
			"multiply": formatted = "×%.2f"%amount
			"override": formatted = "= %.1f"%amount
			"flat":
				if modifier.stat in ["critical_chance","cooldown_reduction"]: formatted = "%+.0f%%"%(amount*100)
		lines.append(t("stat."+str(modifier.stat))+": "+formatted)
	return lines

static func modifier_effects(modifiers: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if int(modifiers.get("projectiles",1))>1: lines.append(t("tip.projectiles")%(int(modifiers.projectiles)-1))
	if int(modifiers.get("chains",0))>0: lines.append(t("tip.chains")%int(modifiers.chains))
	return lines

static func trigger_text(rule: Dictionary) -> String:
	var effect := ""
	match rule.effect:
		"heal": effect = t("tip.heal")%(float(rule.amount)*100)
		"shield","energy": effect = t("tip."+str(rule.effect))%float(rule.amount)
		"ability": effect = t("tip.ability")%t(Database.abilities[rule.ability].name_key)
		"status": effect = t("tip.self_status")%t(Database.statuses[rule.status].name_key)
	var parts: Array[String] = [t("event."+str(rule.event))+": "+effect]
	var conditions: Dictionary = rule.get("conditions",{})
	for key in ["target_status","owner_status"]:
		if conditions.has(key): parts.append(t("tip."+key)%t(Database.statuses[conditions[key]].name_key))
	if conditions.has("health_below"): parts.append(t("tip.health_below")%(float(conditions.health_below)*100))
	parts.append(t("tip.interval")%float(rule.get("cooldown",.3)))
	return "; ".join(parts)

static func trait_text(definition: TraitData) -> String:
	var lines := modifier_lines(definition.modifiers)
	lines.append_array(modifier_effects(definition.ability_mods))
	for rule in definition.triggers: lines.append(trigger_text(rule))
	return "\n".join(lines)

static func item_comparison(item: Dictionary, state: CombatState, ability: AbilityData = null) -> Dictionary:
	var definition: ItemData = Database.items[item.base]
	var held := definition.category==&"held"
	var source := "held" if held else "equipment:"+str(definition.slot)
	var preview := state.stats.copy_for_preview()
	if held: preview.remove_source(source)
	preview.set_source(source,ItemGenerator.modifiers(item))
	var rows: Array[Dictionary] = []
	for id in ["health","attack","defense","speed","critical_chance","cooldown_reduction","energy_regeneration","status_duration"]:
		var before := state.stats.value(id)
		var after := preview.value(id)
		if not is_equal_approx(before,after): rows.append({"id":id,"before":before,"after":after,"delta":after-before})
	var sources := state.ability_modifier_sources.duplicate(true)
	sources[source] = definition.ability_mods.duplicate()
	var result := {"stats":rows,"before_mods":state.ability_mods(),"after_mods":CombatState.combine_ability_mods(sources)}
	if ability!=null:
		result["before_ability"] = ability_values(ability,state)
		result["after_ability"] = ability_values(ability,state,preview)
	return result

static func stat_value(id: String, value: float, signed: bool = false) -> String:
	if id in ["critical_chance","cooldown_reduction"]: return ("%+.1f%%" if signed else "%.1f%%")%(value*100)
	return ("%+.1f" if signed else "%.1f")%value

static func status_values(entry: Dictionary, target: CombatState) -> Dictionary:
	var definition: StatusData = entry.definition
	var source: Dictionary = entry.get("source",{})
	var enabled := definition.tick_power>0 and not source.is_empty() and Factions.hostile(int(source.get("faction",-1)),target.faction) and target.health.current>0
	var normal := 0.0
	var critical := 0.0
	if enabled:
		var damage := DamageSystem.new()
		damage.rules = Database.rules
		var request := {"attack":float(source.get("attack",0)),"defense":target.stats.value("defense"),"power":definition.tick_power*entry.stacks,"element":str(definition.element),"target_types":target.types}
		normal = damage.calculate(request).final_damage
		request["critical"] = true
		critical = damage.calculate(request).final_damage
	var interval := maxf(.001,definition.tick_interval)
	var next_tick := maxf(0,float(entry.tick))
	var ticks := maxi(0,1+floori((float(entry.remaining)-next_tick+.000001)/interval))
	return {"remaining":entry.remaining,"stacks":entry.stacks,"next_tick":next_tick,"ticks":ticks,"damage":normal,"critical_damage":critical,"critical_chance":float(source.get("critical_chance",0)),"damaging":enabled}

static func status_text(entry: Dictionary, target: CombatState) -> String:
	var definition: StatusData = entry.definition
	var values := status_values(entry,target)
	var lines: Array[String] = [t("status.remaining")%[values.remaining,values.stacks,definition.max_stacks]]
	lines.append_array(modifier_lines(definition.modifiers))
	if definition.tick_power>0:
		if values.damaging:
			lines.append(t("status.tick")%[values.next_tick,values.ticks])
			if values.critical_chance>0: lines.append(t("status.damage")%[values.damage,values.critical_damage])
			else: lines.append(t("status.damage_no_crit")%values.damage)
		else: lines.append(t("status.no_damage"))
	for reaction in Database.rules.reactions:
		if str(reaction.status)!=str(definition.id): continue
		var element := t("element."+str(reaction.element))
		if reaction.effect=="chain": lines.append(t("status.reaction_chain")%[element,reaction.count])
		elif reaction.effect=="bonus": lines.append(t("status.reaction_bonus")%[element,reaction.multiplier])
	return "\n".join(lines)

static func item_text(item: Dictionary) -> String:
	var definition: ItemData = Database.items[item.base]
	var lines := modifier_lines(ItemGenerator.modifiers(item))
	lines.append_array(modifier_effects(definition.ability_mods))
	for rule in definition.triggers: lines.append(trigger_text(rule))
	return "\n".join(lines)

static func item_summary(item: Dictionary) -> String:
	if item.is_empty(): return ""
	return t(Database.items[item.base].name_key)+" · "+t("item.rarity."+str(clampi(item.rarity,0,3)))+"\n"+item_text(item)

static func creature_text(creature: CreatureInstance) -> String:
	var species: SpeciesData = Database.species[creature.species_id]
	var state := creature.ensure_combat()
	var lines: Array[String] = [t(species.name_key),t("party.progress")%[creature.level,creature.xp,Progression.threshold(creature.level),state.health.current/maxf(1,state.health.maximum)*100]]
	for id in ["health","attack","defense","speed"]:
		lines.append(t("stat."+id)+": "+stat_value(id,state.stats.value(id)))
	for id in species.passives+creature.traits:
		var definition: TraitData = Database.traits.get(str(id))
		if definition!=null: lines.append(t(definition.name_key)+": "+trait_text(definition))
	return "\n".join(lines)
