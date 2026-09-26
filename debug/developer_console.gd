class_name DeveloperConsole extends RefCounted
var session

func execute(line: String) -> String:
	var args := line.strip_edges().split(" ",false)
	if args.is_empty(): return "Введите help"
	var world: GameWorld = session.world
	match args[0]:
		"help": return "god · spawn <species> · elite <species> · creature <species> · item <id> · level <n> · teleport <x> <y> · kill · area <haven/grove> · seed <n> · status <id> · stress <n> · reset CONFIRM"
		"god": world.trainer.health.immortal = not world.trainer.health.immortal; return "god="+str(world.trainer.health.immortal)
		"kill":
			for actor in world.actors:
				if Factions.hostile(world.trainer.faction,actor.faction): actor.health.damage(actor.health.maximum*2)
		"spawn","elite","creature":
			if args.size()<2 or not Database.species.has("species."+args[1]): return "Неизвестный вид"
			var id := "species."+args[1]
			if args[0]=="creature": session.party.add(CreatureInstance.create(Database.species[id],world.capture.rng))
			else: world.spawn_actor(id,Factions.Team.WILD,world.trainer.position+Vector2(170,0),null,Database.rules.elite_affixes[0] if args[0]=="elite" else {})
		"item":
			if args.size()<2 or not Database.items.has("item."+args[1]): return "Неизвестный предмет"
			session.inventory.add(world.item_generator.generate("item."+args[1]))
		"level":
			if args.size()<2 or not args[1].is_valid_int(): return "Нужен уровень"
			for creature in session.party.roster: creature.level = clampi(int(args[1]),1,100)
			for actor in session.party.active_actors:
				if is_instance_valid(actor): actor.stats.level = actor.individual.level; actor.health.reset(actor.stats.value("health"))
		"teleport":
			if args.size()<3 or not args[1].is_valid_float() or not args[2].is_valid_float(): return "Нужны x y"
			world.trainer.position = Vector2(float(args[1]),float(args[2])).clamp(Vector2(40,80),world.area.size-Vector2(40,40))
			world.camera.snap(world.trainer.position)
		"area":
			if args.size()<2 or not Database.areas.has("area."+args[1]): return "Неизвестная область"
			session.hud.close_panel()
			session.change_area("area."+args[1],false)
		"seed":
			if args.size()<2 or not args[1].is_valid_int(): return "Нужен целочисленный seed"
			session.seed_value = int(args[1])
		"status":
			if args.size()<2 or not Database.statuses.has("status."+args[1]): return "Неизвестный статус"
			world.trainer.statuses.apply("status."+args[1],world.trainer)
		"stress":
			var amount := clampi(int(args[1]) if args.size()>1 else 30,1,60)
			for index in amount: world.spawn_actor("species.cinder",Factions.Team.WILD,world.trainer.position+Vector2.from_angle(index*TAU/amount)*250)
			world.trainer.health.immortal = true
		"reset":
			if args.size()<2 or args[1]!="CONFIRM": return "reset CONFIRM — начать заново (старое сохранение останется до следующего сохранения)"
			session.new_journey()
			session.change_area("area.haven",false)
		_: return "Неизвестная команда. help"
	return "Готово: "+line
