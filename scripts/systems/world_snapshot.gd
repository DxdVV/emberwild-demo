class_name WorldSnapshot extends RefCounted

static func capture(world: GameWorld) -> Dictionary:
	var enemies: Dictionary = {}
	for actor in world.actors:
		if not actor.identity.begins_with("encounter:"): continue
		enemies[actor.identity] = {"health":actor.health.current,"combat":actor.combat.to_dict(),"boss_time":actor.brain.boss_time,"boss_phase":actor.brain.boss_phase,"position":[actor.position.x,actor.position.y]}
	var drops: Array = []
	for drop in world.drops: drops.append({"position":[drop.at.x,drop.at.y],"item":drop.item.duplicate(true)})
	return {"removed":world.removed_ids.duplicate(),"enemies":enemies,"drops":drops,"damage_rng":str(world.damage.rng.state),"capture_rng":str(world.capture.rng.state),"loot_rng":str(world.item_generator.rng.state),"elapsed":world.elapsed,"capture_remaining":world.capture_remaining}

static func restore(world: GameWorld, snapshot: Dictionary) -> void:
	world.removed_ids.assign(snapshot.get("removed",[]))
	for actor in world.actors.duplicate():
		if actor.identity in world.removed_ids:
			world.remove_actor(actor)
			continue
		var data: Dictionary = snapshot.get("enemies",{}).get(actor.identity,{})
		if not data.is_empty():
			if not data.get("combat",{}).is_empty(): actor.combat.restore(data.combat)
			else: actor.health.current = clampf(float(data.health),0,actor.health.maximum)
			actor.brain.boss_time = float(data.get("boss_time",2))
			actor.brain.boss_phase = int(data.get("boss_phase",0))
			var restored := world.navigation.safe_position_near(Vector2(data.position[0],data.position[1]),actor.body_radius)
			actor.position = actor.spawn_origin if restored==Vector2.INF else restored
			if actor.health.current<=0: world.remove_actor(actor)
	world.drops.clear()
	for data in snapshot.get("drops",[]): world.drops.append({"at":Vector2(data.position[0],data.position[1]),"item":data.item.duplicate(true)})
	if snapshot.has("damage_rng"): world.damage.rng.state = int(snapshot.damage_rng)
	if snapshot.has("capture_rng"): world.capture.rng.state = int(snapshot.capture_rng)
	if snapshot.has("loot_rng"): world.item_generator.rng.state = int(snapshot.loot_rng)
	world.elapsed = float(snapshot.get("elapsed",0))
	world.capture_remaining = float(snapshot.get("capture_remaining",0))
	world.refresh_labels()
