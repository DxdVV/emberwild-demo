extends RefCounted

func run(session, check: Callable) -> void:
	for area: AreaData in Database.areas.values():
		check.call(LayoutValidator.validate(area,Database).is_empty(),"authored layout validates: "+str(area.id))
		session.change_area(str(area.id),false)
		var world: GameWorld = session.world
		world.set_physics_process(false)
		for actor in world.actors: actor.set_physics_process(false)
		check.call(world.navigation.obstacles==area.layout.obstacles(),"rendered prop colliders match authored navigation footprints: "+str(area.id))
		var reachable := true
		for segment in area.layout.segments():
			var route := world.navigation.path(area.layout.entry,segment.to)
			reachable = reachable and not route.is_empty() and route[-1].distance_to(segment.to)<1
		check.call(reachable,"every authored path endpoint is reachable from entry: "+str(area.id))
		for interaction in area.layout.interactions:
			var at := AreaLayout.point(interaction.at)
			var route := world.navigation.path(area.layout.entry,at)
			check.call(not route.is_empty() and route[-1].distance_to(at)<1,"interaction is accessible: "+str(interaction.id))
		if area.safe: continue
		var expected: Array[String] = []
		for encounter in area.layout.encounters:
			for index in encounter.positions.size():
				expected.append("encounter:%s:%s"%[area.id,str(encounter.id)+("" if encounter.kind in ["elite","boss"] else ":"+str(index))])
		var actual: Array = world.actors.filter(func(actor): return actor.identity.begins_with("encounter:")).map(func(actor): return actor.identity)
		check.call(expected==actual and actual.size()==13,"authored encounters retain all thirteen stable save identities")
		check.call(world.actors.all(func(actor): return world.navigation.point_clear(actor.position,actor.body_radius)),"every authored spawn has body clearance")
		var snapshot := WorldSnapshot.capture(world)
		var victim: Actor = world.actors.filter(func(actor): return actor.identity.ends_with("pack:0:0"))[0]
		var retained_id := victim.identity
		var obstacle := world.navigation.obstacles[0].get_center()
		snapshot.enemies[retained_id].position = [obstacle.x,obstacle.y]
		WorldSnapshot.restore(world,snapshot)
		check.call(victim.identity==retained_id and world.navigation.point_clear(victim.position) and victim.position.distance_to(obstacle)<=128,"older saved enemy positions are relocated only when new geometry blocks them")
		snapshot = WorldSnapshot.capture(world)
		snapshot.removed.append(retained_id)
		WorldSnapshot.restore(world,snapshot)
		check.call(not world.actors.any(func(actor): return actor.identity==retained_id),"authored placement honors already defeated or captured save identities")
	var original: AreaData = Database.areas["area.grove"]
	var invalid := original.duplicate(true) as AreaData
	invalid.layout.encounters.append(invalid.layout.encounters[0].duplicate(true))
	check.call(not LayoutValidator.validate(invalid,Database).is_empty(),"layout validator rejects duplicate persistent encounter IDs")
	invalid = original.duplicate(true) as AreaData
	invalid.layout.paths[0].points[1] = invalid.layout.paths[0].points[0].duplicate()
	check.call(not LayoutValidator.validate(invalid,Database).is_empty(),"layout validator rejects zero-length road segments")
	invalid = original.duplicate(true) as AreaData
	invalid.layout.props.append({"cell":0,"at":[invalid.layout.entry.x,invalid.layout.entry.y],"height":200,"solid":true})
	check.call(not LayoutValidator.validate(invalid,Database).is_empty(),"layout validator rejects obstacles blocking entry and authored routes")
	invalid = original.duplicate(true) as AreaData
	invalid.layout.encounters[0].positions[0] = [0,0]
	check.call(not LayoutValidator.validate(invalid,Database).is_empty(),"layout validator rejects spawn points outside playable bounds")
	invalid = original.duplicate(true) as AreaData
	for index in 12: invalid.layout.clearings.append(original.layout.clearings[0].duplicate(true))
	check.call(not LayoutValidator.validate(invalid,Database).is_empty(),"layout validator rejects clearing counts beyond shader capacity")
	session.new_journey()
	session.change_area("area.haven",false)
	session.hud.close_panel()
	var saved: Dictionary = session.save_data()
	var blocked: Vector2 = session.world.navigation.obstacles[0].get_center()
	saved.trainer.position = [blocked.x,blocked.y]
	var wrote := SaveStore.write(saved,"user://layout-save-check.json")
	check.call(wrote and session.load_game("user://layout-save-check.json") and session.world.navigation.point_clear(session.world.trainer.position),"loading an older trainer position resolves new prop collisions")
