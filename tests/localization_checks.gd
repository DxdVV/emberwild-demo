extends RefCounted

func settle(tree: SceneTree) -> void:
	for index in 4: await tree.process_frame

func texts(node: Node) -> Array[String]:
	var result: Array[String] = []
	if node is Control and not node.is_visible_in_tree(): return result
	if node is Label or node is BaseButton: result.append(node.text)
	if node is OptionButton:
		for index in node.item_count:
			var value: String = node.get_item_text(index)
			if value!="Русский": result.append(value)
	for child in node.get_children(): result.append_array(texts(child))
	return result

func key(viewport: Viewport, code: Key, shift: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.shift_pressed = shift
	event.pressed = true
	viewport.push_input(event,true)
	var release := event.duplicate()
	release.pressed = false
	viewport.push_input(release,true)

func run(session, check: Callable) -> void:
	var tree: SceneTree = session.get_tree()
	var hud: GameHUD = session.hud
	var original_locale: String = Settings.locale
	var original_path: String = Settings.storage_path
	Settings.storage_path = "user://localization-checks.cfg"
	hud.close_panel(true)
	session.new_journey()
	session.change_area("area.haven",false)
	session.world.set_physics_process(false)
	for actor in session.world.actors: actor.set_physics_process(false)
	hud.show_settings()
	await settle(tree)
	var before: Dictionary = session.trainer_combat.to_dict()
	var identity: int = session.world.get_instance_id()
	var picker: OptionButton = hud.panel.find_child("LanguagePicker",true,false)
	check.call(picker!=null and picker.item_count==2,"settings exposes both supported languages")
	picker.select(1)
	picker.item_selected.emit(1)
	await settle(tree)
	check.call(Settings.locale=="en" and TranslationServer.get_locale()=="en" and texts(hud.panel).has("Settings"),"language selection rebuilds the open settings panel without restart")
	check.call(session.world.get_instance_id()==identity and session.trainer_combat.to_dict()==before and tree.paused,"language switching preserves the paused world and combat state")
	var config := ConfigFile.new()
	check.call(config.load(Settings.storage_path)==OK and config.get_value("general","locale")=="en","selected language persists to settings")
	check.call(session.get_window().title=="Emberwild — Guardians of the Grove","window title follows the selected language")
	check.call(Settings.set_locale("invalid",false)==ERR_INVALID_PARAMETER and Settings.locale=="en","unsupported language cannot replace the active locale")
	var untranslated: Array[String] = []
	var cyrillic := RegEx.new()
	cyrillic.compile("[А-Яа-яЁё]")
	for screen in [hud.show_title,hud.show_pause,hud.show_inventory,hud.show_party,hud.show_settings,hud.show_controls,hud.show_loot_filter,hud.show_camp,hud.show_statuses,hud.show_item_comparison.bind(0)]:
		screen.call()
		await settle(tree)
		for value in texts(hud.panel):
			if cyrillic.search(value)!=null or value.begins_with("menu."): untranslated.append(value)
	check.call(untranslated.is_empty(),"English player menus, item details and selectors contain translated visible text: "+str(untranslated))
	hud.party_expanded_id = ""
	hud.show_party()
	await settle(tree)
	var available := hud.modal_focus.controls()
	check.call(session.get_viewport().gui_get_focus_owner()==available[0],"opening a menu focuses its first content control")
	var scroll := available[0].get_parent()
	while scroll!=null and not scroll is ScrollContainer: scroll = scroll.get_parent()
	check.call(scroll!=null and scroll.get_global_rect().encloses(available[0].get_global_rect()),"initial menu focus is visible after container layout and scrolling")
	available[-1].grab_focus()
	key(session.get_viewport(),KEY_TAB)
	check.call(session.get_viewport().gui_get_focus_owner()==available[0],"Tab wraps inside the modal instead of entering background HUD")
	key(session.get_viewport(),KEY_TAB,true)
	check.call(session.get_viewport().gui_get_focus_owner()==available[-1],"Shift Tab wraps backward inside the modal")
	var expander: Button
	for control in available:
		if control is Button and control.text.begins_with("Skill"):
			expander = control
			break
	if expander!=null: expander.pressed.emit()
	await settle(tree)
	check.call(hud.modal_focus.controls().size()>available.size(),"expanding creature details adds their controls to keyboard traversal")
	hud.show_controls()
	await settle(tree)
	var bindings_before: Dictionary = Settings.inputs.bindings.duplicate(true)
	hud.binding_editor.begin_capture("move_left",0)
	var capture_prompt: String = hud.binding_editor.status.text
	key(session.get_viewport(),KEY_TAB)
	check.call(hud.binding_editor.status.text!=capture_prompt and (not hud.binding_editor.action.is_empty() or Settings.inputs.label("move_left").contains("Tab")),"modal focus does not consume Tab while rebinding controls")
	hud.binding_editor.cancel()
	Settings.inputs.restore(bindings_before)
	hud.show_pause()
	await settle(tree)
	for control in hud.modal_focus.controls():
		if control is Button and control.text=="Continue":
			control.grab_focus()
			key(session.get_viewport(),KEY_ENTER)
			break
	await settle(tree)
	check.call(not hud.panel.visible and not tree.paused,"Enter activates the focused Continue button and resumes gameplay")
	SaveStore.migrate({"save_version":999})
	check.call(SaveStore.last_error=="Unsupported save version: 999","save error messages use the selected language")
	hud._process(.1)
	check.call(hud.header.text==tr("area.haven") and hud.health_text.text.begins_with("RANGER") and hud.objectives.text.begins_with("MEMORY"),"world HUD and objectives refresh to English")
	Settings.set_locale("ru",false)
	hud.show_inventory()
	await settle(tree)
	check.call(texts(hud.panel).has("Рюкзак"),"switching back restores Russian inventory text")
	Settings.storage_path = "user://missing-localization-directory/settings.cfg"
	hud.show_settings()
	await settle(tree)
	picker = hud.panel.find_child("LanguagePicker",true,false)
	picker.item_selected.emit(1)
	await settle(tree)
	check.call(Settings.locale=="en" and texts(hud.panel).has(tr("settings.save_failed")),"language save failure leaves the active locale usable and displays the error inside settings")
	hud.locale_save_error = false
	Settings.storage_path = original_path
	Settings.load_settings()
	Settings.set_locale(original_locale,false)
	hud.close_panel(true)
	await settle(tree)
