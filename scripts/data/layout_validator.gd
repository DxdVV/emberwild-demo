class_name LayoutValidator extends RefCounted

static func point(value, size: Vector2) -> bool:
	return value is Array and value.size()==2 and CombatSaveSchema.number(value[0],0,size.x) and CombatSaveSchema.number(value[1],0,size.y)

static func validate(area: AreaData, registry) -> PackedStringArray:
	var errors := PackedStringArray()
	var id := str(area.id)
	if not area.size.is_finite() or area.size.x<=70 or area.size.y<=110 or area.size.x>100000 or area.size.y>100000: return PackedStringArray([area.resource_path+" / size: expected finite playable area dimensions"])
	if area.level_min<1 or area.level_max<area.level_min or area.level_max>100: return PackedStringArray([area.resource_path+" / level_min/level_max: invalid level range"])
	var layout := area.layout
	if layout==null: return PackedStringArray(["Missing area layout: "+id])
	if not Rect2(Vector2(35,75),area.size-Vector2(70,110)).has_point(layout.entry): errors.append("Invalid entry: "+id)
	var segment_count := 0
	for path in layout.paths:
		if not path.get("points") is Array or path.points.size()<2 or not CombatSaveSchema.number(path.get("width"),40,300):
			errors.append("Invalid path: "+id)
			continue
		segment_count += path.points.size()-1
		for index in path.points.size():
			if not point(path.points[index],area.size): errors.append("Invalid path point: "+id)
			if index>0 and path.points[index]==path.points[index-1]: errors.append("Zero length path: "+id)
	if segment_count<1 or segment_count>32: errors.append("Path shader capacity exceeded or empty: "+id)
	if layout.clearings.size()>12: errors.append("Clearing shader capacity exceeded: "+id)
	for clearing in layout.clearings:
		if not point(clearing.get("at"),area.size) or not point(clearing.get("radii"),area.size) or clearing.get("surface") not in ["dirt","stone"]:
			errors.append("Invalid clearing: "+id)
		elif minf(clearing.radii[0],clearing.radii[1])<20: errors.append("Invalid clearing radius: "+id)
	for prop in layout.props:
		if not point(prop.get("at"),area.size) or not CombatSaveSchema.integer(prop.get("cell"),0,5) or not CombatSaveSchema.number(prop.get("height"),20,500) or not prop.get("solid",false) is bool: errors.append("Invalid prop: "+id)
	for light in layout.lights:
		if not point(light.get("at"),area.size) or not light.get("color") is String or not Color.html_is_valid(light.color) or not CombatSaveSchema.number(light.get("radius"),1,1000) or not CombatSaveSchema.number(light.get("energy"),0,5): errors.append("Invalid light: "+id)
	var identities := {}
	if area.safe and not layout.encounters.is_empty(): errors.append("Hostile encounters in safe area: "+id)
	for encounter in layout.encounters:
		if not encounter.get("id") is String or str(encounter.id).is_empty() or not registry.species.has(encounter.get("species")) or encounter.get("kind") not in ["wild","elite","boss"] or not CombatSaveSchema.integer(encounter.get("level"),area.level_min,area.level_max) or not encounter.get("positions") is Array or encounter.positions.is_empty():
			errors.append("Invalid encounter: "+id)
			continue
		if encounter.kind in ["elite","boss"] and encounter.positions.size()!=1: errors.append("Named encounter must have one persistent identity: "+id)
		if encounter.kind=="elite" and not registry.rules.elite_affixes.any(func(affix): return affix.get("id")==encounter.get("affix")): errors.append("Unknown elite affix: "+id)
		for index in encounter.positions.size():
			if not point(encounter.positions[index],area.size): errors.append("Invalid encounter position: "+id)
			var identity := str(encounter.id)+("" if encounter.kind in ["elite","boss"] else ":"+str(index))
			if identities.has(identity): errors.append("Duplicate encounter identity: "+id)
			identities[identity] = true
	var interactions := {}
	var destinations: Array[String] = []
	for interaction in layout.interactions:
		if not interaction.get("id") is String or str(interaction.id).is_empty() or interactions.has(interaction.id) or not point(interaction.get("at"),area.size) or interaction.get("action") not in ["camp","rest","exit"] or not interaction.get("label") is String or str(interaction.label).is_empty() or not CombatSaveSchema.number(interaction.get("radius"),30,180):
			errors.append("Invalid interaction: "+id)
			continue
		interactions[interaction.id] = true
		if interaction.action=="exit":
			if not registry.areas.has(interaction.get("target")): errors.append("Unknown exit: "+id)
			else: destinations.append(interaction.target)
	for destination in area.exits:
		if destination not in destinations: errors.append("Missing exit interaction: "+id)
	for destination in destinations:
		if destination not in area.exits: errors.append("Undeclared exit interaction: "+id)
	if errors.is_empty(): errors.append_array(geometry(area))
	return errors

static func geometry(area: AreaData) -> PackedStringArray:
	var errors := PackedStringArray()
	var navigation := WorldNavigation.new()
	navigation.configure(area.size,area.layout.obstacles())
	if not navigation.point_clear(area.layout.entry): errors.append("Blocked area entry: "+str(area.id))
	for segment in area.layout.segments():
		if not navigation.segment_clear(segment.from,segment.to): errors.append("Blocked authored path: %s %s -> %s"%[area.id,segment.from,segment.to])
	for interaction in area.layout.interactions:
		if not navigation.point_clear(AreaLayout.point(interaction.at)): errors.append("Blocked interaction: "+str(area.id)+":"+str(interaction.id))
	for encounter in area.layout.encounters:
		for position in encounter.positions:
			if not navigation.point_clear(AreaLayout.point(position),32 if encounter.kind=="boss" else 14): errors.append("Blocked encounter: "+str(area.id)+":"+str(encounter.id))
	return errors
