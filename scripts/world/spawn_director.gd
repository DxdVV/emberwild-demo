class_name SpawnDirector extends RefCounted

func populate(world: GameWorld) -> void:
	for encounter in world.area.layout.encounters:
		var faction := Factions.Team.WILD
		if encounter.kind=="elite": faction = Factions.Team.HOSTILE
		elif encounter.kind=="boss": faction = Factions.Team.BOSS
		var affix: Dictionary = {}
		for candidate in Database.rules.elite_affixes:
			if candidate.id==encounter.get("affix",""): affix = candidate
		for index in encounter.positions.size():
			var actor := world.spawn_actor(encounter.species,faction,AreaLayout.point(encounter.positions[index]),null,affix)
			# Keep existing encounter IDs compatible with saved defeats/captures.
			var suffix := str(encounter.id)+("" if encounter.kind in ["elite","boss"] else ":"+str(index))
			actor.identity = "encounter:%s:%s" % [world.area.id,suffix]
			actor.stats.level = int(encounter.level)
			actor.health.reset(actor.stats.value("health"))
