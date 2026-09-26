extends Node

var session

func _ready() -> void: run.call_deferred()

func frame(path: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/"+path+".png")
	print("VISUAL ",path)

func run() -> void:
	session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	session.autosave_remaining = 100000
	await frame("title-final")
	session.hud.close_panel()
	await frame("haven-final")
	session.hud.show_inventory()
	await frame("inventory-final")
	session.hud.show_party()
	await frame("party-final")
	var creature: CreatureInstance = session.party.roster[0]
	creature.level = 3
	creature.refresh_stats()
	Progression.select_command(creature,"ability.breath")
	session.hud.party_expanded_id = creature.persistent_id
	session.hud.show_party()
	await frame("party-skill-final")
	session.hud.show_settings()
	await frame("settings-final")
	session.hud.close_panel()
	session.change_area("area.grove",false)
	session.world.trainer.health.immortal = true
	session.world.trainer.position = Vector2(1940,965)
	session.world.camera.snap(session.world.trainer.position)
	for actor in session.party.active_actors: actor.position = session.world.trainer.position+Vector2(-40,40)
	for tick in 120: await get_tree().physics_frame
	var boss: Actor = session.world.actors.filter(func(actor): return actor.faction==Factions.Team.BOSS)[0]
	boss.brain.boss_time = .01
	for tick in 20: await get_tree().physics_frame
	await frame("boss-final")
	Audio.shutdown()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()
