extends RefCounted

func registry_copy():
	var registry = load("res://scripts/data/database.gd").new()
	for kind in ContentFields.KINDS: registry.set(kind,Database.get(kind).duplicate())
	registry.rules = Database.rules.duplicate(true)
	return registry

func run(check: Callable) -> void:
	var registry = registry_copy()
	check.call(registry.validate().is_empty(),"independent registry validates current authored content")
	var mutations := [
		["abilities","ability.spark","windup",NAN,"windup"],
		["abilities","ability.spark","recovery",-1.0,"recovery"],
		["abilities","ability.spark","projectile_speed",0.0,"projectile_speed"],
		["abilities","ability.spark","power",INF,"power"],
		["abilities","ability.spark","cooldown",3601.0,"cooldown"],
		["abilities","ability.spark","charges",1001,"charges"],
		["statuses","status.burn","duration",NAN,"duration"],
		["statuses","status.burn","duration",3601.0,"duration"],
		["statuses","status.burn","tick_interval",0.0,"tick_interval"],
		["statuses","status.burn","max_stacks",0,"max_stacks"],
		["statuses","status.burn","max_stacks",1001,"max_stacks"],
		["statuses","status.burn","tick_power",-2.0,"tick_power"],
		["species","species.cinder","capture_rate",1.5,"capture_rate"],
		["species","species.cinder","visual_height",INF,"visual_height"],
		["species","species.cinder","base_stats",{"health":NAN,"attack":5,"defense":1,"speed":20},"base_stats.health"],
		["species","species.cinder","base_stats",{"health":20},"missing base stat"],
		["species","species.cinder","element",&"typo","element"],
		["items","item.boots","rarity",4,"rarity"],
		["items","item.boots","slot",&"","slot"],
		["traits","swift","category",&"typo","category"],
		["areas","area.grove","size",Vector2(INF,1200),"size"],
		["areas","area.grove","level_max",0,"level_max"]]
	for mutation in mutations:
		var table: Dictionary = registry.get(mutation[0])
		var original: Resource = table[mutation[1]]
		var copy := original.duplicate(false)
		copy.set(mutation[2],mutation[3])
		table[mutation[1]] = copy
		var errors: PackedStringArray = registry.validate()
		check.call(not errors.is_empty() and str(errors).contains(mutation[4]),"content rejects invalid "+mutation[1]+"."+mutation[2])
		check.call(registry.validate()==errors,"repeated validation does not duplicate errors for "+mutation[2])
		table[mutation[1]] = original
	check.call(registry.validate().is_empty(),"repair removes stale validation errors")
	var original_animation: SpriteAnimationData = registry.animations["animation.ranger"]
	for mutation in [{"region":["broken",0,10,10]},{"region":[0,0,NAN,10]},{"anchor":[INF,5]},{"source":8},{"source":"absent"},{"visible_bounds":[0,0,INF,10]}]:
		var copy: SpriteAnimationData = original_animation.duplicate(false)
		copy.frames = original_animation.frames.duplicate(true)
		copy.frames[0].merge(mutation,true)
		var errors := AnimationValidator.validate(copy)
		check.call(not errors.is_empty() and str(errors).contains("frames[0]"),"malformed animation frame is diagnosed without throwing: "+str(mutation.keys()[0]))
	var animation: SpriteAnimationData = original_animation.duplicate(false)
	animation.directions = {"east":[-1],"north":"broken"}
	animation.idle_frame = animation.frames.size()
	var animation_errors := AnimationValidator.validate(animation)
	check.call(str(animation_errors).contains("directions.east[0]") and str(animation_errors).contains("directions.north") and str(animation_errors).contains("idle_frame"),"animation diagnostics locate broken sequences and idle frame")
	check.call(AnimationValidator.validate(original_animation).is_empty(),"animation validation leaves source metadata unchanged")
	var original_rules: RulesData = registry.rules
	for field in ["item_affixes","elite_affixes"]:
		registry.rules = original_rules.duplicate(true)
		var affixes: Array = registry.rules.get(field)
		affixes.append(affixes[0].duplicate(true))
		check.call(str(registry.validate()).contains("duplicate affix ID"),"duplicate IDs rejected in "+field)
		registry.rules = original_rules.duplicate(true)
		registry.rules.get(field)[0]["modifiers"] = ["broken"]
		check.call(str(registry.validate()).contains("expected modifier dictionary"),"nested invalid modifiers diagnosed in "+field)
		registry.rules.get(field)[0]["triggers"] = 4
		check.call(str(registry.validate()).contains("expected trigger array"),"nested invalid triggers diagnosed in "+field)
	registry.rules = original_rules.duplicate(true)
	registry.rules.type_chart["fire"] = ["bad"]
	check.call(str(registry.validate()).contains("type_chart.fire"),"malformed type-chart row is diagnosed")
	registry.rules = original_rules.duplicate(true)
	registry.rules.reactions[0]["count"] = -1
	check.call(str(registry.validate()).contains("reactions[0].count"),"invalid reaction chain count is diagnosed")
	registry.rules = original_rules.duplicate(true)
	registry.rules.boss_phases[1]["threshold"] = 1.0
	registry.rules.boss_phases[2]["waves"] = "bad"
	check.call(str(registry.validate()).contains("descend strictly") and str(registry.errors).contains("boss_phases[2].waves"),"boss phase ordering and wave types are validated")
	registry.rules = original_rules.duplicate(true)
	registry.rules.boss_phases.clear()
	check.call(str(registry.validate()).contains("at least one phase"),"empty boss phases fail before gameplay")
	registry.rules = original_rules.duplicate(true)
	registry.rules.type_chart["ice"] = {"fire":.5}
	var species: SpeciesData = registry.species["species.cinder"].duplicate(false)
	species.element = &"ice"
	registry.species["species.cinder"] = species
	var item: ItemData = registry.items["item.boots"].duplicate(false)
	item.slot = &"hat"
	registry.items["item.boots"] = item
	check.call(registry.validate().is_empty(),"new declared elements and trainer slots remain data-driven")
	registry.species["species.cinder"] = Database.species["species.cinder"]
	registry.items["item.boots"] = Database.items["item.boots"]
	registry.rules = null
	check.call(str(registry.validate()).contains("missing RulesData"),"missing rules report a validation error without dereferencing null")
	registry.rules = original_rules
	registry.species["bad"] = Resource.new()
	check.call(str(registry.validate()).contains("wrong Resource type"),"wrong registry resource type is rejected before typed iteration")
	registry.species.erase("bad")
	check.call(not registry.register("species",Resource.new(),"res://bad-kind.tres") and not registry.species.has("bad"),"loader rejects wrong resource class without reading absent id")
	var first: SpeciesData = registry.species["species.cinder"]
	var second: SpeciesData = first.duplicate(false)
	second.base_stats = {"health":1,"attack":1,"defense":1,"speed":1}
	check.call(not registry.register("species",second,"res://duplicate-cinder.tres") and registry.species["species.cinder"]==first,"duplicate registration preserves the original resource")
	check.call(str(registry.validate()).contains("duplicate-cinder.tres") and str(registry.errors).contains(first.resource_path),"duplicate diagnostics identify both source paths")
	var errors: PackedStringArray = registry.errors.duplicate()
	check.call(registry.validate()==errors,"load-time errors persist once across revalidation")
	registry.free()
	check.call(Database.validate().is_empty(),"negative authoring checks leave live game content intact")
