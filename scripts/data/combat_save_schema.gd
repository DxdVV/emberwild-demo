class_name CombatSaveSchema extends RefCounted

static func number(value, minimum: float = 0, maximum: float = 1e12) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=minimum and value<=maximum

static func integer(value, minimum: int = 0, maximum: int = 1000000) -> bool:
	return number(value,minimum,maximum) and float(value)==floorf(float(value))

static func valid(data) -> bool:
	if not data is Dictionary: return false
	for key in ["shield","energy"]:
		if not number(data.get(key,0)): return false
	if not number(data.get("health_ratio",1),0,1): return false
	for key in ["invulnerable","dodge_cooldown"]:
		if not number(data.get(key,0),0,60): return false
	var cooldowns = data.get("cooldowns",{})
	if not cooldowns is Dictionary or not cooldowns.get("timers",{}) is Dictionary or not cooldowns.get("charges",{}) is Dictionary: return false
	if not number(cooldowns.get("global",0),0,60): return false
	for timer in cooldowns.get("timers",{}).values():
		if not timer is Dictionary or not number(timer.get("remaining"),0,3600) or not number(timer.get("base"),.001,3600): return false
	for count in cooldowns.get("charges",{}).values():
		if not integer(count,0,1000): return false
	if not data.get("triggers",{}) is Dictionary: return false
	for remaining in data.get("triggers",{}).values():
		if not number(remaining,0,3600): return false
	var statuses = data.get("statuses",[])
	if not statuses is Array or statuses.size()>512: return false
	for status in statuses:
		if not status is Dictionary or not status.get("id","") is String: return false
		if not number(status.get("remaining",0),0,StatusData.MAX_DURATION) or not number(status.get("tick",0),0,StatusData.MAX_DURATION) or not integer(status.get("stacks",1),1,1000): return false
		var source = status.get("source",{})
		if not source is Dictionary: return false
		if not source.is_empty():
			if not source.get("id") is String or not integer(source.get("faction"),0,Factions.Team.NEUTRAL): return false
			if not number(source.get("attack")) or not number(source.get("critical_chance",0),0,1): return false
	return true
