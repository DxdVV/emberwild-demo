extends Node

var session
var mode: String = "menu"
var expected: Dictionary
var frames_alive: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	run.call_deferred()

func _process(_delta: float) -> void:
	frames_alive += 1
	if frames_alive>120:
		push_error("EXIT RUNTIME did not quit after successful save")
		get_tree().quit(1)

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--exit-mode="): mode = argument.get_slice("=",1)
	session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	session.autosave_remaining = 100000
	session.inventory.currency = 731
	session.hud.show_pause()
	for frame in 4: await get_tree().process_frame
	expected = session.save_data()
	SaveStore.storage_path = "user://missing-exit-directory/journey.json"
	activate_exit()
	for frame in 4: await get_tree().process_frame
	var stayed: bool = session.get_tree().paused and session.save_data()==expected and session.hud.panel_notice.visible and session.hud.panel_notice.text.contains(tr("save.exit_failed"))
	print("EXIT RUNTIME failure_preserves_game=",stayed," mode=",mode)
	if not stayed: get_tree().quit(1); return
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/save-exit-"+mode+"-failed.png")
	SaveStore.storage_path = "user://exit-runtime-"+mode+".json"
	activate_exit()
	var restored := SaveStore.read_save("",SavedJourney.valid)
	var saved: bool = not restored.is_empty() and restored.inventory.currency==731 and restored.party==JSON.parse_string(JSON.stringify(expected.party))
	if not saved:
		print("EXIT RUNTIME retry_error=",SaveStore.last_error," file_exists=",FileAccess.file_exists(SaveStore.storage_path)," notice=",session.hud.panel_notice.text)
		var diagnostic := FileAccess.open("res://build/exit-diff.json",FileAccess.WRITE)
		diagnostic.store_string(JSON.stringify({"expected":expected,"actual":restored},"\t"))
		diagnostic.close()
	print("EXIT RUNTIME successful_retry=",saved," mode=",mode)
	if not saved: get_tree().quit(1)
	# Successful request_exit already queued quit; _process enforces that it exits.

func activate_exit() -> void:
	if mode=="window":
		get_window().close_requested.emit()
	else:
		var button := find_exit(session.hud.panel)
		if button==null: get_tree().quit(1); return
		button.grab_focus()
		var press := InputEventKey.new()
		press.keycode = KEY_ENTER
		press.physical_keycode = KEY_ENTER
		press.pressed = true
		get_viewport().push_input(press,true)
		var release := press.duplicate()
		release.pressed = false
		get_viewport().push_input(release,true)

func find_exit(node: Node) -> Button:
	if node is Button and node.text==tr("menu.quit"): return node
	for child in node.get_children():
		var found := find_exit(child)
		if found!=null: return found
	return null
