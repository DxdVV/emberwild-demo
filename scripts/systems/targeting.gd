class_name TargetingSystem extends RefCounted

static func valid(source, target) -> bool:
	return is_instance_valid(source) and is_instance_valid(target) and target.health.current > 0 and target.visible and Factions.hostile(source.faction,target.faction)

static func nearest(source, actors: Array, origin: Vector2, reach: float, excluded: Array = []):
	var selected = null
	var distance := reach * reach
	for actor in actors:
		if actor in excluded or not valid(source,actor): continue
		var candidate: float = origin.distance_squared_to(actor.global_position)
		if candidate < distance:
			distance = candidate
			selected = actor
	return selected

static func area(source, actors: Array, origin: Vector2, radius: float) -> Array:
	return actors.filter(func(actor): return valid(source,actor) and origin.distance_squared_to(actor.global_position) <= radius*radius)

static func cone(source, actors: Array, direction: Vector2, reach: float, angle: float) -> Array:
	return area(source,actors,source.global_position,reach).filter(func(actor): return absf(direction.angle_to(actor.global_position-source.global_position)) <= angle * 0.5)
