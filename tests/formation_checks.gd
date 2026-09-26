extends RefCounted

func run(session, check: Callable) -> void:
	var actors: Array = session.party.active_actors
	check.call(actors[0].brain.follow_offset()==Vector2(-65,35) and actors[1].brain.follow_offset()==Vector2(50,45),"companion formation follows active slots rather than engine object IDs")
	var saved: Array = actors.duplicate()
	actors.reverse()
	check.call(saved[0].brain.follow_offset()==Vector2(50,45) and saved[1].brain.follow_offset()==Vector2(-65,35),"changing slots changes formation without reallocating the actors")
	actors.reverse()
	var world: GameWorld = session.world
	var at := world.area.layout.entry+Vector2(0,80)
	var first := world.spawn_actor("species.cinder",Factions.Team.WILD,at)
	var second := world.spawn_actor("species.cinder",Factions.Team.WILD,at)
	first.set_physics_process(false)
	second.set_physics_process(false)
	first.brain.steer(at+Vector2(30,0),.016)
	second.brain.steer(at+Vector2(30,0),.016)
	check.call(first.get_instance_id()!=second.get_instance_id() and first.brain.route_remaining==second.brain.route_remaining,"identical spawn data gives identical repath cadence across object allocations")
	world.remove_actor(first)
	world.remove_actor(second)
