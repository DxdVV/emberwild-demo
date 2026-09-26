class_name AreaLayout extends Resource

# Authored geometry and encounter placement. Coordinates are in world units.
@export var entry := Vector2(170,510)
@export var paths: Array[Dictionary] = []
@export var clearings: Array[Dictionary] = []
@export var props: Array[Dictionary] = []
@export var lights: Array[Dictionary] = []
@export var encounters: Array[Dictionary] = []
@export var interactions: Array[Dictionary] = []

static func point(value: Array) -> Vector2:
	return Vector2(value[0],value[1])

static func footprint(prop: Dictionary) -> Rect2:
	var size := Vector2(float(prop.height)*.23,22)
	return Rect2(point(prop.at)-size*.5,size)

func obstacles() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for prop in props:
		if prop.get("solid",false): result.append(footprint(prop))
	return result

func segments() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for path in paths:
		for index in range(1,path.points.size()):
			result.append({"from":point(path.points[index-1]),"to":point(path.points[index]),"width":float(path.width)})
	return result
