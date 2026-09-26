class_name StatsComponent extends RefCounted

var base: Dictionary = {}
var level: int = 1
var _sources: Dictionary = {}
var _compiled: Dictionary = {}
var scaling: float = 0.14

func value(stat: String) -> float:
	var initial: float = float(base.get(stat,0.0))
	if stat in ["health","attack","defense"]: initial *= 1.0 + (level - 1) * scaling
	var result := initial
	if _compiled.has(stat):
		var terms: Array = _compiled[stat]
		result = float(terms[3]) if terms[3]!=null else (initial+terms[0])*(1.0+terms[1])*terms[2]
	# Bound the final probability, not individual modifiers. Removing gear must
	# reveal its original contributions, and previews/source snapshots must agree.
	return clampf(result,0,1) if stat=="critical_chance" else maxf(0,result)

func set_source(id: String, values: Array) -> void:
	if _sources.has(id) and _sources[id]==values: return
	_sources[id] = values.duplicate(true)
	rebuild_modifiers()

func remove_source(id: String) -> void:
	if _sources.erase(id): rebuild_modifiers()

func copy_for_preview() -> StatsComponent:
	var result := StatsComponent.new()
	result.base = base.duplicate(true)
	result.level = level
	result.scaling = scaling
	result._sources = _sources.duplicate(true)
	result.rebuild_modifiers()
	return result

func rebuild_modifiers() -> void:
	# Compile only source-dependent terms. Base values, level and scaling remain live,
	# including direct base-stat edits in developer tools and content restoration.
	_compiled.clear()
	for source in _sources.values():
		for modifier in source:
			var stat: String = modifier.get("stat","")
			if not _compiled.has(stat): _compiled[stat] = [0.0,0.0,1.0,null]
			var terms: Array = _compiled[stat]
			var amount: float = modifier.get("value",0.0)
			match modifier.get("op","flat"):
				"flat": terms[0] += amount
				"add": terms[1] += amount
				"multiply": terms[2] *= amount
				"override": terms[3] = amount
