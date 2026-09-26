class_name DamageSystem extends RefCounted

signal resolved(request: Dictionary, result: Dictionary)
var rules: RulesData
var rng := RandomNumberGenerator.new()

static func critical_roll(chance: float, roll: float) -> bool:
	# randf can include its upper endpoint. A 100% chance must still be guaranteed;
	# callers always draw once, preserving the seeded stream even at 0% and 100%.
	return chance>=1 or roll<chance

func calculate(request: Dictionary) -> Dictionary:
	var attack: float = request.get("attack",0)
	var defense: float = request.get("defense",0)
	var power: float = request.get("power",1)
	var element: String = request.get("element","neutral")
	var effectiveness := 1.0
	for target_type in request.get("target_types",[]):
		effectiveness *= float(rules.type_chart.get(element,{}).get(str(target_type),1.0))
	var critical: bool = request.get("critical",false)
	var raw: float = request.get("base_damage",attack * power)
	var amount := maxf(0,raw * effectiveness * (1.5 if critical else 1.0) / (1.0 + maxf(0,defense)*rules.defense_factor))
	return {"final_damage":amount,"effectiveness":effectiveness,"critical":critical,"resisted":effectiveness<1,"applied_statuses":[]}

func apply(source, target, ability: AbilityData, context: Dictionary = {}) -> Dictionary:
	if not TargetingSystem.valid(source,target): return {}
	var request := {"source_id":source.identity,"target_id":target.identity,"ability":str(ability.id),"attack":source.stats.value("attack"),"defense":target.stats.value("defense"),"power":ability.power,"element":str(context.get("element",ability.element)),"target_types":target.types,"critical":critical_roll(source.critical_chance,rng.randf()),"tags":ability.tags}
	if context.has("base_damage"): request.base_damage = context.base_damage
	var result := calculate(request)
	result.merge(target.health.damage(result.final_damage),true)
	result.final_damage = result.damage
	if not result.blocked:
		target.presentation.hit()
		for effect in ability.effects:
			match effect.get("kind"):
				"status":
					if target.health.current > 0:
						target.statuses.apply(effect.id,source,float(effect.get("duration_bonus",0)))
						result.applied_statuses.append(effect.id)
				"knockback":
					if target.health.current>0: target.external_velocity += (target.global_position-source.global_position).normalized()*float(effect.get("force",100))
		source.triggers.fire("hit",{"target":target,"depth":context.get("depth",0)})
		if result.critical: source.triggers.fire("critical",{"target":target,"depth":context.get("depth",0)})
		if result.killed: source.triggers.fire("kill",{"target":target,"depth":context.get("depth",0)})
		target.triggers.fire("damage_taken",{"target":source,"depth":context.get("depth",0)})
	resolved.emit(request,result)
	return result

func apply_periodic(source: Dictionary, target: CombatState, id: String, status: StatusData, stacks: int) -> Dictionary:
	if source.is_empty() or not Factions.hostile(int(source.faction),target.faction) or target.health.current<=0: return {}
	var request := {"source_id":source.id,"target_id":target.identity,"ability":id+".tick","attack":float(source.attack),"defense":target.stats.value("defense"),"power":status.tick_power*stacks,"element":str(status.element),"target_types":target.types,"critical":critical_roll(float(source.get("critical_chance",0)),rng.randf()),"tags":["periodic"]}
	var result := calculate(request)
	result.merge(target.health.damage(result.final_damage),true)
	result.final_damage = result.damage
	var actor = target.actor_ref.get_ref() if target.actor_ref != null else null
	if is_instance_valid(actor) and not result.blocked: actor.presentation.hit()
	# Periodic damage does not recursively trigger on-hit effects.
	resolved.emit(request,result)
	return result
