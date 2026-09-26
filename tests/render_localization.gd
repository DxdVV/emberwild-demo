extends Node

var session
var failed: bool = false
var helpers := preload("res://tests/localization_checks.gd").new()

func _ready() -> void: run.call_deferred()

func verify(value: bool, message: String) -> void:
	print("LOCALIZATION ",message," verified=",value)
	if not value: failed = true

func window_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.window_id = get_window().get_window_id()
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	var release := event.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()

func frame(label: String) -> void:
	await helpers.settle(get_tree())
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/localization-"+label+".png")
	var bounds := Rect2(Vector2.ZERO,get_viewport().get_visible_rect().size)
	verify(bounds.encloses(session.hud.panel.get_global_rect()),label+" panel fits viewport")
	var focused := get_viewport().gui_get_focus_owner()
	if focused!=null:
		var scroll := focused.get_parent()
		while scroll!=null and not scroll is ScrollContainer: scroll = scroll.get_parent()
		if scroll!=null: verify(scroll.get_global_rect().encloses(focused.get_global_rect()),label+" focused control visible")

func run() -> void:
	get_viewport().gui_embed_subwindows = true
	var original_path: String = Settings.storage_path
	var original_locale: String = Settings.locale
	Settings.storage_path = "user://render-localization.cfg"
	Settings.set_locale("ru",false)
	session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	session.autosave_remaining = 100000
	var hud: GameHUD = session.hud
	hud.show_settings()
	await frame("settings-ru")
	var picker: OptionButton = hud.panel.find_child("LanguagePicker",true,false)
	verify(get_viewport().gui_get_focus_owner()==picker,"language picker receives initial keyboard focus")
	window_key(KEY_SPACE)
	await helpers.settle(get_tree())
	verify(picker.get_popup().visible,"keyboard opens language selector")
	window_key(KEY_DOWN)
	window_key(KEY_ENTER)
	await helpers.settle(get_tree())
	verify(Settings.locale=="en" and helpers.texts(hud.panel).has("Settings"),"keyboard selection changes locale and open menu")
	await frame("settings-en")
	for entry in [["title",hud.show_title],["pause",hud.show_pause],["inventory",hud.show_inventory],["party",hud.show_party],["camp",hud.show_camp],["controls",hud.show_controls],["filter",hud.show_loot_filter]]:
		entry[1].call()
		await frame(entry[0]+"-en")
	hud.show_controls()
	await helpers.settle(get_tree())
	var last: Control = hud.modal_focus.controls()[-2]
	last.grab_focus()
	await frame("controls-bottom-en")
	verify(last.get_global_rect().end.y<hud.panel.get_global_rect().end.y,"keyboard focus scrolls lower binding rows into view")
	hud.close_panel()
	for actor in session.world.actors: actor.set_physics_process(false)
	session.world.set_physics_process(false)
	await helpers.settle(get_tree())
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/localization-world-en.png")
	session.world.trainer.health.current = 0
	session.world.trainer.on_defeated()
	for tick in 80: await get_tree().process_frame
	verify(hud.panel.visible and helpers.texts(hud.panel).has("The lantern still burns"),"defeat animation leads to the localized recovery menu")
	await frame("defeat-en")
	Settings.storage_path = original_path
	Settings.set_locale(original_locale,false)
	Audio.shutdown()
	await helpers.settle(get_tree())
	print("LOCALIZATION COMPLETE verified=",not failed)
	get_tree().quit(1 if failed else 0)
