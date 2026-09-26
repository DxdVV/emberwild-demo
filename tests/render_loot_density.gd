extends Node

var session

func _ready() -> void: run.call_deferred()

func capture(name: String) -> void:
	for index in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var labels: WorldLabels = session.hud.world_labels
	for index in labels.label_rects.size():
		for reserved in labels.reserved_rects: assert(not labels.label_rects[index].intersects(reserved))
		for previous in index:
			assert(not labels.label_rects[previous].grow(2).intersects(labels.label_rects[index]))
	assert(not labels.label_rects.is_empty())
	assert(session.world.loot_markers.instances.instance_count==session.world.visible_drops().size())
	get_viewport().get_texture().get_image().save_png("res://build/"+name+".png")
	print("LOOT DENSITY ",name," visible_indices=",labels.ordered_drops.size()," placed=",labels.label_rects.size()," selected=",session.world.pickup_candidate())

func run() -> void:
	var old_filter := Settings.loot_filter.to_dict()
	var old_locale := TranslationServer.get_locale()
	Settings.loot_filter.restore({})
	Settings.changed.emit()
	session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	session.autosave_remaining = 100000
	session.hud.close_panel()
	session.change_area("area.grove",false)
	var world: GameWorld = session.world
	world.set_physics_process(false)
	for actor in world.actors: actor.set_physics_process(false)
	world.trainer.position = Vector2(1190,1000)
	for index in session.party.active_actors.size(): session.party.active_actors[index].position = world.trainer.position+Vector2(-45+90*index,50)
	world.camera.snap(world.trainer.position)
	for index in 120:
		var at := world.trainer.position+Vector2(index%15*35-245,(index/15)*30-105)
		world.drops.append({"at":at,"item":world.item_generator.generate("item.ember",3,index%4)})
	world.refresh_labels()
	await capture("loot-density-all")
	assert(session.hud.world_labels.ordered_drops.size()==120)
	var selected := world.pickup_candidate()
	var id: String = world.drops[selected].item.id
	world.interact()
	assert(session.inventory.items.any(func(item): return item.id==id) and world.drops.size()==119)
	await capture("loot-density-picked")
	Settings.loot_filter.restore({"minimum_rarity":3})
	Settings.changed.emit()
	await capture("loot-density-filtered")
	assert(session.hud.world_labels.ordered_drops.size()==world.visible_drops().size())
	world.reveal_loot = true
	world.refresh_labels()
	await capture("loot-density-revealed")
	assert(session.hud.world_labels.ordered_drops.size()==119)
	world.trainer.health.shield = 50
	session.hud.refresh_status_strips()
	await capture("loot-density-status")
	assert(session.hud.status_strips[0].visible)
	world.trainer.health.shield = 0
	session.hud.refresh_status_strips()
	session.hud.notification_remaining = 0
	session.hud._process(0)
	await capture("loot-density-hud-clear")
	TranslationServer.set_locale("en")
	await capture("loot-density-english")
	world.trainer.position += Vector2(90,40)
	world.camera.snap(world.trainer.position)
	await capture("loot-density-moved")
	Settings.loot_filter.restore(old_filter)
	TranslationServer.set_locale(old_locale)
	Settings.changed.emit()
	Audio.shutdown()
	for index in 3: await get_tree().process_frame
	print("LOOT DENSITY verified=true")
	get_tree().quit()
