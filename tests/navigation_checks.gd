extends RefCounted

func clear_route(nav: WorldNavigation, start: Vector2, route: PackedVector2Array, radius: float = 14) -> bool:
	var at := start
	for point in route:
		if not nav.segment_clear(at,point,radius): return false
		at = point
	return true

func run(check: Callable) -> void:
	var nav := WorldNavigation.new()
	nav.configure(Vector2(600,600),[Rect2(266,196,68,168)])
	var start := Vector2(242,300)
	var target := Vector2(430,300)
	var route := nav.path(start,target)
	check.call(route.size()>1 and route[-1]==target and clear_route(nav,start,route),"navigation escapes a blocked grid cell from a physically clear starting point")
	check.call(not nav.segment_clear(Vector2(230,190),Vector2(280,175)),"navigation rejects a segment clipping an expanded obstacle corner")
	check.call(not nav.segment_clear(Vector2(300,250),Vector2(300,300)),"navigation rejects segments wholly inside an obstacle")
	check.call(not nav.segment_clear(Vector2(250,170),Vector2(250,390)),"navigation rejects tangency to a collision clearance boundary")
	var count := nav.searches
	var direct := nav.path(Vector2(80,100),Vector2(180,100))
	check.call(direct.size()==1 and nav.searches==count,"unobstructed movement uses a direct path without AStar search")
	var blocked_goal := nav.path(start,Vector2(300,280))
	check.call(not blocked_goal.is_empty() and clear_route(nav,start,blocked_goal) and nav.point_clear(blocked_goal[-1]),"blocked destination resolves to a reachable clear endpoint")
	check.call(nav.path(Vector2(300,280),target).is_empty(),"navigation does not steer a body already embedded in solid geometry")
	var recovery := nav.safe_position_near(Vector2(300,280))
	check.call(recovery!=Vector2.INF and nav.point_clear(recovery) and recovery.distance_to(Vector2(300,280))<=128,"recovery selects a nearby collision-clear position")
	check.call(nav.safe_position_near(Vector2(-500,-500))==nav.bounds.position,"recovery clamps off-map positions into the playable bounds")
	# 64-pixel passage admits the ordinary 28-pixel body, but not the 64-pixel boss.
	nav.configure(Vector2(600,600),[Rect2(260,0,60,260),Rect2(260,324,60,276)])
	start = Vector2(170,292)
	target = Vector2(430,292)
	var small := nav.path(start,target,14)
	var large := nav.path(start,target,32)
	check.call(not small.is_empty() and small[-1]==target and clear_route(nav,start,small,14),"ordinary actor passes a narrow opening with body clearance")
	check.call((large.is_empty() or large[-1].distance_to(target)>100) and clear_route(nav,start,large,32),"boss cannot reuse a route through a gap narrower than its body")
	nav.configure(Vector2(600,600),[Rect2(200,180,40,240),Rect2(200,380,220,40),Rect2(380,180,40,240)])
	start = Vector2(300,320)
	target = Vector2(480,450)
	route = nav.path(start,target)
	check.call(route.size()>=3 and route[-1]==target and clear_route(nav,start,route),"U-shaped obstruction produces a safe route around the open end")
	var old_revision := nav.revision
	nav.configure(Vector2(600,600),[])
	check.call(nav.revision>old_revision and nav.path(start,target).size()==1,"geometry revision invalidates obsolete blocked routes")
	var grove: AreaData = Database.areas["area.grove"]
	nav.configure(grove.size,grove.layout.obstacles())
	start = Vector2(35.44413,305.8614) # Actual position recorded by the journey pilot.
	target = Vector2(1400,460)
	check.call(nav.point_clear(start) and nav.closest_cell(start,nav.grid_for(14),14,true)==WorldNavigation.INVALID_CELL,"edge-strip regression begins clear but has no directly visible grid cell")
	route = nav.path(start,target)
	check.call(route.size()>1 and route[-1]==target and clear_route(nav,start,route),"bounded local bend connects the playable edge strip to AStar without crossing geometry")
