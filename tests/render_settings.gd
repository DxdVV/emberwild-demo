extends Node

var session

func _ready() -> void: run.call_deferred()

func frame(name: String) -> void:
	for index in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/"+name+".png")
	print("VISUAL ",name)

func run() -> void:
	var original_path: String = Settings.storage_path
	Settings.storage_path = "user://render-settings.cfg"
	Settings.persist()
	var previous := FileAccess.get_file_as_string(Settings.storage_path)
	Settings.inputs.reset()
	session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	session.autosave_remaining = 100000
	session.hud.show_controls()
	await frame("controls-final")
	session.hud.binding_editor.begin_capture("move_left",0)
	var conflict := InputEventKey.new()
	conflict.physical_keycode = KEY_D
	conflict.pressed = true
	Input.parse_input_event(conflict)
	Input.flush_buffered_events()
	await frame("controls-conflict")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	Input.flush_buffered_events()
	conflict.pressed = false
	escape.pressed = false
	Input.parse_input_event(conflict.duplicate())
	Input.parse_input_event(escape.duplicate())
	Input.flush_buffered_events()
	Settings.inputs.assign("interact",0,{"kind":"key","code":KEY_G})
	Settings.loot_filter.restore({"minimum_rarity":2})
	Settings.persist()
	session.hud.show_loot_filter()
	await frame("loot-filter-final")
	session.hud.close_panel()
	var world: GameWorld = session.world
	world.set_physics_process(false)
	for actor in world.actors: actor.set_physics_process(false)
	var generator := ItemGenerator.new()
	generator.rng.seed = 498
	for entry in [["item.ember",0,Vector2(-70,-20)],["item.prism",2,Vector2(85,15)],["item.relic",3,Vector2(180,-30)]]:
		world.drop_item(world.trainer.position+entry[2],generator.generate(entry[0],1,entry[1]))
	await frame("loot-filtered-world")
	world.reveal_loot = true
	world.queue_redraw()
	await frame("loot-revealed-world")
	var restore := FileAccess.open(Settings.storage_path,FileAccess.WRITE)
	restore.store_string(previous)
	restore.close()
	Settings.load_settings()
	Settings.storage_path = original_path
	Audio.shutdown()
	for index in 3: await get_tree().process_frame
	get_tree().quit()
