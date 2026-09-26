extends Node

var species: Dictionary = {}
var abilities: Dictionary = {}
var statuses: Dictionary = {}
var items: Dictionary = {}
var areas: Dictionary = {}
var animations: Dictionary = {}
var traits: Dictionary = {}
var rules: RulesData
var errors: PackedStringArray = []
var load_errors: PackedStringArray = []

func _ready() -> void:
	for kind in ContentFields.KINDS:
		var files := ResourceLoader.list_directory("res://resources/" + kind)
		files.sort()
		for file in files:
			if not file.ends_with(".tres"): continue
			var path: String = "res://resources/" + kind + "/" + file
			register(kind,load(path),path)
	rules = load("res://resources/rules.tres")
	validate()
	for problem in errors: push_error(problem)

func register(kind: String, entry, path: String) -> bool:
	if not ContentFields.accepts(kind,entry):
		load_errors.append(path+": wrong or missing "+kind+" Resource")
		return false
	if str(entry.id).is_empty():
		load_errors.append(path+" / id: empty content identity")
		return false
	var table: Dictionary = get(kind)
	if table.has(str(entry.id)):
		load_errors.append("Duplicate ID %s: %s and %s"%[entry.id,table[str(entry.id)].resource_path,path])
		return false
	table[str(entry.id)] = entry
	return true

func validate() -> PackedStringArray:
	errors = load_errors.duplicate()
	var shape := ContentFields.registry(self)
	if not shape.is_empty():
		errors.append_array(shape)
		return errors
	errors.append_array(ContentValidator.validate(self))
	for entry: SpeciesData in species.values():
		if not str(entry.animation_id).is_empty() and not animations.has(str(entry.animation_id)): errors.append("Missing animation in "+str(entry.id))
		for ability in entry.abilities:
			if not abilities.has(ability): errors.append("Missing ability %s in %s" % [ability,entry.id])
		var visited: Array = []
		var current: String = str(entry.id)
		while not current.is_empty():
			if current in visited:
				errors.append("Evolution cycle: " + current)
				break
			visited.append(current)
			if not species.has(current):
				errors.append("Missing evolution: " + current)
				break
			current = str(species[current].evolution_target)
	for entry: AbilityData in abilities.values():
		for effect in entry.effects:
			if effect.get("kind") == "status" and not statuses.has(effect.get("id")): errors.append("Missing status in " + str(entry.id))
	for entry: AreaData in areas.values():
		errors.append_array(LayoutValidator.validate(entry,self))
	for entry: SpriteAnimationData in animations.values():
		errors.append_array(AnimationValidator.validate(entry))
	return errors
