class_name TriggerComponent extends RefCounted

var owner_actor
var rules: Array = []
var cooldowns: Dictionary = {}
var sources: Dictionary = {}
const MAX_DEPTH := 3

func set_source(id: String, values: Array) -> void:
	sources[id] = values.duplicate(true)
	rules.clear()
	for source in sources:
		for rule in sources[source]:
			var copy: Dictionary = rule.duplicate(true)
			copy["_legacy_key"] = JSON.stringify(rule)
			copy["_key"] = source+"|"+copy._legacy_key
			rules.append(copy)

func conditions_match(rule: Dictionary, context: Dictionary) -> bool:
	var conditions: Dictionary = rule.get("conditions",{})
	var target = context.get("target")
	if conditions.has("target_status") and (not is_instance_valid(target) or not target.statuses.entries.has(conditions.target_status)): return false
	if conditions.has("owner_status") and not owner_actor.statuses.entries.has(conditions.owner_status): return false
	if conditions.has("health_below") and owner_actor.health.current/owner_actor.health.maximum>=float(conditions.health_below): return false
	return true

func tick(delta: float) -> void:
	for key in cooldowns.keys(): cooldowns[key] = maxf(0,cooldowns[key]-delta)

func fire(event: String, context: Dictionary = {}) -> void:
	if not is_instance_valid(owner_actor) or owner_actor.health.current<=0: return
	var depth: int = context.get("depth",0)
	if depth >= MAX_DEPTH: return
	for index in rules.size():
		var rule: Dictionary = rules[index]
		# Stable signatures survive save JSON and changes in equipment ordering.
		var legacy_key: String = rule.get("_legacy_key",JSON.stringify(rule))
		var key: String = rule.get("_key",legacy_key)
		if rule.get("event") != event or cooldowns.get(key,cooldowns.get(legacy_key,0))>0 or not conditions_match(rule,context): continue
		cooldowns[key] = float(rule.get("cooldown",0.3))
		match rule.get("effect"):
			"heal": owner_actor.health.heal(owner_actor.health.maximum * float(rule.get("amount",0.04)))
			"shield": owner_actor.health.shield = minf(owner_actor.health.maximum*0.4,owner_actor.health.shield + float(rule.get("amount",10)))
			"energy": owner_actor.energy.current = minf(owner_actor.energy.maximum,owner_actor.energy.current+float(rule.get("amount",0)))
			"status": owner_actor.statuses.apply(str(rule.get("status","")),owner_actor)
			"ability":
				var target = context.get("target")
				var id: String = rule.get("ability","")
				if Database.abilities.has(id) and TargetingSystem.valid(owner_actor,target): owner_actor.world.launch(owner_actor,target,Database.abilities[id],{"depth":depth+1})
