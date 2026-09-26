class_name WorldNavigation extends RefCounted

const CELL := 16
const DEFAULT_RADIUS := 14.0
const INVALID_CELL := Vector2i(-1,-1)
var obstacles: Array[Rect2] = []
var bounds := Rect2()
var grids: Dictionary = {}
var revision: int = 0
var searches: int = 0

func configure(size: Vector2, blocked: Array[Rect2]) -> void:
	obstacles = blocked.duplicate()
	bounds = Rect2(Vector2(35,75),size-Vector2(70,110))
	grids.clear()
	revision += 1
	searches = 0

func point_clear(at: Vector2, radius: float = DEFAULT_RADIUS) -> bool:
	if not bounds.has_point(at): return false
	for rect in obstacles:
		if rect.grow(radius+2).has_point(at): return false
	return true

func segment_clear(from: Vector2, to: Vector2, radius: float = DEFAULT_RADIUS) -> bool:
	if not point_clear(from,radius) or not point_clear(to,radius): return false
	for raw in obstacles:
		var rect := raw.grow(radius+2)
		var low := 0.0
		var high := 1.0
		var delta := to-from
		var intersects := true
		for axis in 2:
			if absf(delta[axis])<.00001:
				if from[axis]<rect.position[axis] or from[axis]>rect.end[axis]:
					intersects = false
					break
			else:
				var a: float = (rect.position[axis]-from[axis])/delta[axis]
				var b: float = (rect.end[axis]-from[axis])/delta[axis]
				low = maxf(low,minf(a,b))
				high = minf(high,maxf(a,b))
				if low>high:
					intersects = false
					break
		if intersects: return false
	return true

func grid_for(radius: float) -> AStarGrid2D:
	var key := ceili(radius)
	if grids.has(key): return grids[key]
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0,0,ceili(bounds.end.x/CELL)+1,ceili(bounds.end.y/CELL)+1)
	grid.cell_size = Vector2(CELL,CELL)
	grid.offset = Vector2.ONE*CELL*.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for x in grid.region.size.x:
		for y in grid.region.size.y:
			var cell := Vector2i(x,y)
			if not bounds.has_point(grid.get_point_position(cell)): grid.set_point_solid(cell)
	for raw in obstacles:
		var rect := raw.grow(key+2)
		var first := Vector2i((rect.position/float(CELL)).floor())
		var last := Vector2i((rect.end/float(CELL)).floor())
		for x in range(maxi(0,first.x),mini(last.x+1,grid.region.size.x)):
			for y in range(maxi(0,first.y),mini(last.y+1,grid.region.size.y)):
				grid.set_point_solid(Vector2i(x,y))
	grids[key] = grid
	return grid

func closest_cell(at: Vector2, grid: AStarGrid2D, radius: float, visible_from_point: bool) -> Vector2i:
	var center := Vector2i((at/float(CELL)).floor())
	var best := INVALID_CELL
	var best_distance := INF
	for ring in range(7):
		for x in range(center.x-ring,center.x+ring+1):
			for y in range(center.y-ring,center.y+ring+1):
				if ring>0 and abs(x-center.x)!=ring and abs(y-center.y)!=ring: continue
				var cell := Vector2i(x,y)
				if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell): continue
				var point := grid.get_point_position(cell)
				var distance := at.distance_squared_to(point)
				if distance>=best_distance: continue
				if visible_from_point and not segment_clear(at,point,radius): continue
				best = cell
				best_distance = distance
		if best!=INVALID_CELL: break
	return best

func path(from: Vector2, to: Vector2, radius: float = DEFAULT_RADIUS) -> PackedVector2Array:
	var stamp := CombatProfiler.start()
	var result := calculate_path(from,to,radius)
	CombatProfiler.finish("navigation",stamp)
	return result

func calculate_path(from: Vector2, to: Vector2, radius: float) -> PackedVector2Array:
	if not point_clear(from,radius): return PackedVector2Array()
	to = to.clamp(bounds.position,bounds.end-Vector2.ONE)
	if segment_clear(from,to,radius): return PackedVector2Array([to])
	var grid := grid_for(radius)
	var first := closest_cell(from,grid,radius,true)
	var entry := from
	if first==INVALID_CELL:
		# A physically clear point can lie between the world edge and a blocked grid
		# cell. Find a short, collision-free bend out of that sub-cell strip.
		var best := INF
		for distance in [16.0,32.0,64.0,96.0]:
			for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
				var candidate: Vector2 = from+direction*distance
				if not segment_clear(from,candidate,radius): continue
				var cell := closest_cell(candidate,grid,radius,true)
				if cell==INVALID_CELL: continue
				var cost: float = distance+candidate.distance_to(grid.get_point_position(cell))
				if cost<best:
					best = cost
					entry = candidate
					first = cell
	var last := closest_cell(to,grid,radius,point_clear(to,radius))
	if first==INVALID_CELL or last==INVALID_CELL: return PackedVector2Array()
	searches += 1
	var raw := grid.get_point_path(first,last,true)
	if raw.is_empty(): return raw
	if segment_clear(raw[-1],to,radius): raw.append(to)
	var result := PackedVector2Array()
	var anchor := entry
	if entry!=from: result.append(entry)
	var index := 0
	while index<raw.size():
		var farthest := index
		for next in range(index,raw.size()):
			if not segment_clear(anchor,raw[next],radius): break
			farthest = next
		if not segment_clear(anchor,raw[farthest],radius): return PackedVector2Array()
		result.append(raw[farthest])
		anchor = raw[farthest]
		index = farthest+1
	return result

func direction(from: Vector2, to: Vector2, radius: float = DEFAULT_RADIUS) -> Vector2:
	var route := path(from,to,radius)
	for point in route:
		if from.distance_squared_to(point)>.25: return from.direction_to(point)
	return Vector2.ZERO

func safe_position_near(at: Vector2, radius: float = DEFAULT_RADIUS, reach: float = 128) -> Vector2:
	at = at.clamp(bounds.position,bounds.end-Vector2.ONE)
	if point_clear(at,radius): return at
	var grid := grid_for(radius)
	var center := Vector2i((at/float(CELL)).floor())
	var limit := ceili(reach/CELL)
	var best := Vector2.INF
	var best_distance := reach*reach
	for x in range(center.x-limit,center.x+limit+1):
		for y in range(center.y-limit,center.y+limit+1):
			var cell := Vector2i(x,y)
			if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell): continue
			var point := grid.get_point_position(cell)
			var distance := at.distance_squared_to(point)
			if distance<best_distance:
				best = point
				best_distance = distance
	return best
