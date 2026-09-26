extends Node

var session
var failed: bool = false
var checked: int = 0

func _ready() -> void: run.call_deferred()

func verify(value: bool, message: String) -> void:
	checked += 1
	failed = failed or not value
	print("STATUS KEYBOARD ",message," verified=",value)

func settle(count: int = 6) -> void:
	for frame in count: await get_tree().process_frame

func wait_description() -> void:
	# Native VSync does not guarantee a fixed number of callbacks per second.
	# Match the tooltip's process-time delay, including its throttled refresh.
	await get_tree().create_timer(ContextTooltip.DELAY+.3,true,false,true).timeout
	await settle()

func key(code: Key, shift: bool = false) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.window_id = get_window().get_window_id()
		event.keycode = code
		event.physical_keycode = code
		event.shift_pressed = shift
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await settle(2)

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/status-keyboard-"+label+".png")

func selected_effect() -> String:
	var focused := get_viewport().gui_get_focus_owner()
	return str(focused.get_meta("status_effect_id","")) if is_instance_valid(focused) else ""

func run() -> void:
	get_viewport().gui_embed_subwindows = true
	session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	session.autosave_remaining = 100000
	var original_locale: String = Settings.locale
	Settings.set_locale("ru",false)
	await settle()
	var hud: GameHUD = session.hud
	hud.close_panel(true)
	await key(KEY_ESCAPE)
	await settle()
	verify(get_tree().paused and hud.panel.visible,"Escape opens pause menu from gameplay")
	var trainer: Actor = session.world.trainer
	var source: Actor = session.party.active_actors[0]
	for id in Database.statuses: trainer.statuses.apply(id,source)
	trainer.health.shield = 30
	source.statuses.apply("status.poison",trainer)
	var before: Dictionary = trainer.combat.to_dict()
	var at_before := trainer.position
	var rng_before: int = session.world.damage.rng.state
	for step in 16:
		var control := get_viewport().gui_get_focus_owner()
		if control is Button and control.text==tr("status.title"): break
		await key(KEY_TAB)
	await key(KEY_ENTER)
	await settle()
	verify(get_tree().paused and get_viewport().gui_get_focus_owner() is OptionButton,"keyboard opens effect inspection and focuses owner picker")
	var ids: Array[String] = ["shield"]
	var statuses: Array = Database.statuses.keys()
	statuses.sort()
	for id in statuses: ids.append(str(id))
	for id in ids:
		await key(KEY_TAB)
		await wait_description()
		var focused := get_viewport().gui_get_focus_owner()
		var visible_rect := hud.context_tooltip.visible_rect(focused) if is_instance_valid(focused) else Rect2()
		verify(selected_effect()==id and visible_rect.has_area() and visible_rect.encloses(focused.get_global_rect()),"Tab reaches and scrolls to "+id)
		verify(hud.context_tooltip.visible and hud.context_tooltip.description.text==StatusHover.describe(weakref(trainer.combat),id),"focused description matches "+id)
		if id=="status.burn" or id==ids[-1]: await capture(id.replace("status.",""))
	await key(KEY_TAB,true)
	verify(selected_effect()==ids[-2],"Shift+Tab selects preceding effect")
	await key(KEY_D)
	verify(trainer.combat.to_dict()==before and trainer.position==at_before and session.world.damage.rng.state==rng_before,"inspection and movement keys leave paused combat and RNG untouched")
	# Return to owner picker and use its native popup keyboard path.
	for step in ids.size()-1: await key(KEY_TAB,true)
	verify(get_viewport().gui_get_focus_owner() is OptionButton,"reverse traversal returns to owner picker")
	await key(KEY_ENTER)
	await key(KEY_DOWN)
	await key(KEY_ENTER)
	await settle()
	await key(KEY_TAB)
	await wait_description()
	verify(selected_effect()=="status.poison" and hud.context_tooltip.description.text==StatusHover.describe(weakref(source.combat),"status.poison"),"native owner selection replaces trainer effects with companion effects")
	await capture("companion")
	# Click a non-first live badge and require focus on that exact effect.
	for actor in session.world.actors: actor.set_physics_process(false)
	session.world.set_physics_process(false)
	await key(KEY_ESCAPE)
	hud.refresh_status_strips()
	var strip: StatusStrip = hud.status_strips[0]
	var badge_index := strip.badges.find_custom(func(badge): return badge.id=="status.slow")
	for pressed in [true,false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = strip.global_position+Vector2(badge_index*StatusStrip.BADGE_WIDTH+8,25)
		click.pressed = pressed
		get_viewport().push_input(click,true)
	await wait_description()
	verify(get_tree().paused and selected_effect()=="status.slow" and hud.context_tooltip.visible,"clicking a live badge focuses its corresponding inspector entry")
	Settings.set_locale("en",false)
	await wait_description()
	verify(selected_effect()=="status.slow" and hud.context_tooltip.description.text.begins_with("Slow"),"language rebuild preserves clicked effect and translates description")
	await capture("english")
	# A live strip can lag a real swap by one HUD refresh. Its displayed owner wins.
	hud.close_panel(true)
	hud.refresh_status_strips()
	var old_state: CombatState = session.party.roster[0].ensure_combat()
	var companion_strip: StatusStrip = hud.status_strips[1]
	session.party.swap_remaining = 0
	session.party.swap(2,0)
	for pressed in [true,false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = companion_strip.global_position+Vector2(8,25)
		click.pressed = pressed
		get_viewport().push_input(click,true)
	await wait_description()
	verify(selected_effect()=="status.poison" and hud.context_tooltip.visible and hud.context_tooltip.description.text==StatusHover.describe(weakref(old_state),"status.poison"),"same-frame party swap cannot retarget a displayed effect to another owner")
	# A pending preferred focus must never escape into a replacement menu.
	hud.show_statuses(-1,"status.burn")
	hud.show_inventory()
	await settle()
	verify(is_instance_valid(get_viewport().gui_get_focus_owner()) and hud.panel.is_ancestor_of(get_viewport().gui_get_focus_owner()) and selected_effect().is_empty(),"menu replacement discards stale preferred focus")
	trainer.statuses.clear()
	trainer.health.shield = 0
	hud.show_statuses(-1,"status.burn")
	await settle()
	verify(get_viewport().gui_get_focus_owner() is OptionButton and not hud.context_tooltip.visible,"expired preferred effect falls back safely to owner picker")
	trainer.set_physics_process(true)
	await key(KEY_ESCAPE)
	var resumed_at := trainer.position
	for pressed in [true,false]:
		var move := InputEventKey.new()
		move.physical_keycode = KEY_D
		move.keycode = KEY_D
		move.pressed = pressed
		Input.parse_input_event(move)
		Input.flush_buffered_events()
		for tick in 15: await get_tree().physics_frame
	verify(not get_tree().paused and trainer.position.x>resumed_at.x+15,"Escape resumes ordinary keyboard movement")
	Settings.set_locale(original_locale,false)
	Audio.shutdown()
	await settle()
	print("STATUS KEYBOARD RUNTIME checks=",checked," verified=",not failed)
	get_tree().quit(1 if failed else 0)
