class_name AnimationValidator extends RefCounted

static func validate(definition: SpriteAnimationData) -> PackedStringArray:
	var errors := PackedStringArray()
	var at := "%s [%s]"%[definition.resource_path,definition.id]
	for field in ["render_scale","stride_per_frame","death_duration","hurt_duration"]:
		if not CombatSaveSchema.number(definition.get(field),.001,10000): errors.append(at+" / "+field+": expected a positive finite number")
	if not CombatSaveSchema.number(definition.death_ground_phase,.001,1): errors.append(at+" / death_ground_phase: expected (0, 1]")
	if definition.texture==null or definition.frames.is_empty(): errors.append(at+" / frames: missing texture or frames")
	if definition.idle_frame<0 or definition.idle_frame>=definition.frames.size(): errors.append(at+" / idle_frame: index outside frames")
	errors.append_array(frames(definition.frames,definition,false,at+" / frames"))
	errors.append_array(frames(definition.action_frames,definition,true,at+" / action_frames"))
	for key in definition.directions:
		if str(key) not in ["east","west","north","south"]: errors.append(at+" / directions: unknown facing "+str(key))
		errors.append_array(sequence(definition.directions[key],definition.frames.size(),at+" / directions."+str(key)))
	for key in definition.clips:
		errors.append_array(sequence(definition.clips[key],definition.action_frames.size(),at+" / clips."+str(key)))
	return errors

static func numbers(value, count: int, minimum: float = -1000000) -> bool:
	return value is Array and value.size()==count and value.all(func(number): return CombatSaveSchema.number(number,minimum,1000000))

static func frames(values: Array, definition: SpriteAnimationData, action: bool, at: String) -> PackedStringArray:
	var errors := PackedStringArray()
	for index in values.size():
		var frame = values[index]
		var field := at+"["+str(index)+"]"
		if not frame is Dictionary:
			errors.append(field+": expected a dictionary")
			continue
		if not frame.get("source","") is String:
			errors.append(field+".source: expected a string")
			continue
		var texture := definition.texture_for(frame,action)
		if texture==null or not CombatSaveSchema.number(definition.scale_for(frame,action),.001,10000):
			errors.append(field+".source: missing texture or positive finite scale")
			continue
		if not numbers(frame.get("region"),4,0):
			errors.append(field+".region: expected four finite nonnegative numbers")
			continue
		if not numbers(frame.get("anchor"),2): errors.append(field+".anchor: expected two finite numbers")
		var region := Rect2(frame.region[0],frame.region[1],frame.region[2],frame.region[3])
		if region.size.x<=0 or region.size.y<=0 or not Rect2(Vector2.ZERO,texture.get_size()).encloses(region): errors.append(field+".region: rectangle outside atlas or empty")
		if frame.has("visible_bounds"):
			var bounds = frame.visible_bounds
			if not numbers(bounds,4,0): errors.append(field+".visible_bounds: expected four finite nonnegative numbers")
			elif bounds[2]<=0 or bounds[3]<=0 or not Rect2(Vector2.ZERO,region.size).encloses(Rect2(bounds[0],bounds[1],bounds[2],bounds[3])): errors.append(field+".visible_bounds: rectangle outside frame or empty")
	return errors

static func sequence(value, count: int, at: String) -> PackedStringArray:
	var errors := PackedStringArray()
	if not value is Array or value.is_empty(): return PackedStringArray([at+": expected a nonempty frame-index array"])
	for index in value.size():
		if not value[index] is int or value[index]<0 or value[index]>=count: errors.append(at+"["+str(index)+"]: frame index out of range")
	return errors
