extends Node

var session

func _ready() -> void: run.call_deferred()

func capture(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/"+name+".png")
	print("INSPECTION ",name)

func run() -> void:
	session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	session.autosave_remaining = 100000
	session.hud.close_panel()
	var generator := ItemGenerator.new()
	generator.rng.seed = 301
	session.inventory.items.clear()
	session.inventory.add(generator.generate("item.ember",2,1))
	session.equip(0,0)
	session.inventory.add(generator.generate("item.prism",2,2))
	session.inventory.add(generator.generate("item.boots",2,1))
	session.hud.show_inventory()
	await capture("inventory-inspection")
	session.hud.show_item_comparison(0)
	await capture("comparison-held")
	session.hud.show_item_comparison(1)
	await capture("comparison-trainer")
	var source: Actor = session.world.spawn_actor("species.rill",Factions.Team.WILD,Vector2(800,600))
	source.set_physics_process(false)
	source.stats.base.attack = 80
	var target: Actor = session.party.active_actors[0]
	for effect in ["status.burn","status.burn","status.slow"]: target.statuses.apply(effect,source)
	session.hud.show_statuses(0)
	await capture("status-companion")
	source.statuses.apply("status.wet",target)
	session.world.focus_target = source
	session.hud.show_statuses(-2)
	await capture("status-target")
	TranslationServer.set_locale("en")
	session.hud.show_item_comparison(0)
	await capture("comparison-en")
	session.hud.show_statuses(0)
	await capture("status-en")
	TranslationServer.set_locale("ru")
	session.hud.show_item_comparison(0)
	var candidate_id: String = session.inventory.items[0].id
	var equip_button: Button = session.hud.panel_content.get_child(session.hud.panel_content.get_child_count()-1)
	equip_button.pressed.emit()
	assert(session.party.roster[0].held_item.id==candidate_id)
	print("INSPECTION comparison equip action verified")
	Audio.shutdown()
	await get_tree().process_frame
	print("INSPECTION RENDERS COMPLETE")
	get_tree().quit()
