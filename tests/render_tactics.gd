extends Node

func _ready() -> void: run.call_deferred()

func run() -> void:
	var session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	session.autosave_remaining = 100000
	session.hud.close_panel()
	session.change_area("area.grove",false)
	var world: GameWorld = session.world
	world.set_physics_process(false)
	for actor in world.actors.duplicate():
		if actor!=world.trainer: world.remove_actor(actor)
	world.trainer.position = Vector2(900,650)
	world.trainer.set_physics_process(false)
	world.camera.snap(world.trainer.position)
	var rng := RandomNumberGenerator.new()
	rng.seed = 81
	for entry in [["cinder","breath"],["rill","frost"],["briar","sweep"],["volt","discharge"]]:
		var individual := CreatureInstance.create(Database.species["species."+entry[0]],rng)
		individual.traits = []
		individual.level = 3
		Progression.select_command(individual,"ability."+entry[1])
		var source := world.spawn_actor(individual.species_id,Factions.Team.COMPANION,Vector2(940,650),individual)
		source.set_physics_process(false)
		var victims: Array[Actor] = []
		for offset in [Vector2(100,0),Vector2(100,50),Vector2(-80,80)]:
			var victim := world.spawn_actor("species.briar",Factions.Team.WILD,source.position+offset)
			victim.set_physics_process(false)
			victims.append(victim)
		source.last_direction = Vector2.RIGHT
		var cast_started := source.abilities.cast(source.ability_id(1),victims[0])
		for index in 34:
			source.abilities.tick(1.0/60)
			source.presentation.tick(1.0/60)
			for victim in victims: victim.presentation.tick(1.0/60)
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/tactic-"+entry[1]+".png")
		print("VISUAL tactic-",entry[1])
		print("TACTIC ",entry[1]," cast=",cast_started," health=",victims.map(func(actor): return actor.health.current)," phase=",source.abilities.phase)
		world.remove_actor(source)
		for victim in victims: world.remove_actor(victim)
		for frame in 70: await get_tree().process_frame
	Audio.shutdown()
	for frame in 3: await get_tree().process_frame
	get_tree().quit()
