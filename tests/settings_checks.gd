extends RefCounted

func key(code: int, pressed: bool = true, ctrl: bool = false, shift: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.ctrl_pressed = ctrl
	event.shift_pressed = shift
	return event

func run(session, check: Callable) -> void:
	# Never overwrite the user's real preferences during a test.
	var original_path: String = Settings.storage_path
	Settings.storage_path = "user://test-settings.cfg"
	Settings.persist()
	var original_config := FileAccess.get_file_as_string(Settings.storage_path)
	Settings.inputs.reset()
	var bindings: InputBindings = Settings.inputs
	var before := bindings.bindings.duplicate(true)
	check.call(not bindings.assign("ability_one",0,{"kind":"key","code":KEY_E}) and bindings.bindings==before,"conflicting input assignment is rejected atomically")
	check.call(bindings.assign("ability_one",0,{"kind":"key","code":KEY_Z}) and InputMap.event_is_action(key(KEY_Z),"ability_one",true) and not InputMap.event_is_action(key(KEY_Q),"ability_one",true),"remapping replaces the actual input event")
	check.call(bindings.assign("ability_one",1,{"kind":"mouse","code":MOUSE_BUTTON_XBUTTON1}) and InputMap.action_get_events("ability_one").size()==2,"actions accept an alternate mouse binding")
	check.call(bindings.remove("ability_one",0) and not bindings.remove("ability_one",0),"removal preserves at least one usable binding")
	check.call(not bindings.assign("attack",0,{"kind":"key","code":KEY_ESCAPE}),"Escape remains reserved as an emergency menu key")
	var chord := key(KEY_3,true,false,true)
	check.call(InputMap.event_is_action(chord,"swap_second_3",true) and not InputMap.event_is_action(chord,"swap_three",true),"shift swap matches only the second companion slot")
	Input.action_press("move_right")
	bindings.apply()
	check.call(not Input.is_action_pressed("move_right"),"rebuilding bindings releases held actions")
	var invalid := bindings.bindings.duplicate(true)
	invalid.move_left = []
	check.call(not bindings.restore(invalid) and InputMap.action_get_events("move_left").size()==2,"invalid empty saved binding falls back to playable defaults")
	invalid = bindings.bindings.duplicate(true)
	invalid.attack = [{"kind":"mouse","code":MOUSE_BUTTON_WHEEL_UP}]
	check.call(not bindings.restore(invalid),"wheel impulses cannot become held gameplay bindings")
	invalid = bindings.bindings.duplicate(true)
	invalid.ability_one = invalid.ability_two.duplicate(true)
	check.call(not bindings.restore(invalid),"duplicate saved assignments restore defaults without ambiguous actions")
	session.hud.show_controls()
	var editor: BindingEditor = session.hud.binding_editor
	editor.begin_capture("ability_one",0)
	editor._input(key(KEY_CTRL,true,true))
	check.call(Settings.capturing_input and editor.action=="ability_one","modifier press waits for a chord instead of binding prematurely")
	editor._input(key(KEY_K,true,true))
	check.call(not Settings.capturing_input and InputMap.event_is_action(key(KEY_K,true,true),"ability_one",true) and not InputMap.event_is_action(key(KEY_K),"ability_one",true),"capture accepts a modifier chord with exact matching")
	var previous := bindings.bindings.duplicate(true)
	editor.begin_capture("interact",0)
	editor._input(key(KEY_ESCAPE))
	session._unhandled_input(key(KEY_ESCAPE))
	check.call(bindings.bindings==previous and session.hud.panel.visible and not Settings.capturing_input,"Escape cancels rebinding without changing keys or closing the settings panel")
	editor.begin_capture("focus",0)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_MIDDLE
	mouse.pressed = true
	editor._input(mouse)
	check.call(bindings.label("focus")==TranslationServer.translate("input.mouse.3") and InputMap.event_is_action(mouse,"focus",true),"binding editor captures mouse buttons and shows their localized name")
	editor.begin_capture("show_all_loot",0)
	editor._input(key(KEY_SHIFT))
	editor._input(key(KEY_SHIFT,false))
	check.call(bindings.label("show_all_loot")=="Shift","standalone modifier binding is accepted on release")
	editor.begin_capture("capture",0)
	session.hud.close_panel()
	check.call(not Settings.capturing_input and editor.action.is_empty(),"closing the panel cancels pending input capture")
	for frame in 4: await session.get_tree().process_frame
	bindings.assign("move_right",0,{"kind":"key","code":KEY_L})
	bindings.assign("interact",0,{"kind":"key","code":KEY_G})
	Settings.loot_filter.restore({"minimum_rarity":2,"categories":{"held":true,"trainer":false},"always_unique":true})
	Settings.effects_quality = 1
	Settings.shake = false
	Settings.fullscreen = true
	Settings.volumes.SFX = .25
	check.call(Settings.persist()==OK,"settings persist bindings graphics sound and loot filter to the selected file")
	var saved := bindings.bindings.duplicate(true)
	bindings.reset()
	Settings.loot_filter.restore({})
	Settings.load_settings()
	check.call(Settings.inputs.bindings==saved and Settings.loot_filter.minimum_rarity==2 and not Settings.loot_filter.categories.trainer and Settings.fullscreen and not Settings.shake and Settings.effects_quality==1 and Settings.volumes.SFX==.25,"settings reload restores all preference groups")
	check.call(FileAccess.file_exists(Settings.storage_path+".bak") and not FileAccess.file_exists(Settings.storage_path+".tmp"),"atomic preference commit retains a backup and consumes its temporary file")
	check.call("L" in session.hud.control_hint.text and "G" in session.hud.control_hint.text,"HUD hints refresh when bindings change")
	check.call(session.world.interaction_markers().values().all(func(text): return text.begins_with("G · ")),"world interaction labels use the remapped action")
	session.world.trainer.set_physics_process(false)
	Input.parse_input_event(key(KEY_L))
	Input.flush_buffered_events()
	session.world.trainer.player_tick(.01)
	check.call(session.world.trainer.velocity.x>0,"remapped physical key drives actual player movement")
	Input.parse_input_event(key(KEY_L,false))
	Input.flush_buffered_events()
	session.world.trainer.player_tick(.01)
	check.call(session.world.trainer.velocity.x==0,"releasing the remapped key stops movement")
	verify_loot(session,check)
	var labels: WorldLabels = session.hud.world_labels
	labels.label_rects.clear()
	var first := labels.place("First drop",Vector2(400,250))
	var second := labels.place("Second drop",Vector2(400,250))
	check.call(first.has_area() and second.has_area() and not first.intersects(second),"overlapping world labels are separated in the readable UI layer")
	var origin := labels.project(Vector2.ZERO)
	var right := labels.project(Vector2(100,0))
	check.call(is_equal_approx(right.x-origin.x,100),"label projection accounts for the coarse world viewport scale")
	var malformed := ConfigFile.new()
	malformed.set_value("graphics","effects",99)
	malformed.set_value("audio","SFX",NAN)
	malformed.set_value("input","bindings",{"move_up":"bad"})
	malformed.set_value("loot","filter",{"minimum_rarity":-5,"categories":{"held":"bad"}})
	malformed.save(Settings.storage_path)
	Settings.load_settings()
	check.call(Settings.effects_quality==2 and Settings.volumes.SFX==Settings.DEFAULT_VOLUMES.SFX and Settings.loot_filter.minimum_rarity==0 and Settings.loot_filter.categories.held and Settings.inputs.label("move_up")=="W","malformed preferences recover safe defaults")
	var legacy := ConfigFile.new()
	legacy.set_value("audio","SFX",.3)
	legacy.save(Settings.storage_path)
	Settings.load_settings()
	check.call(Settings.volumes.SFX==.3 and Settings.inputs.label("ability_one")=="Q" and Settings.loot_filter.accepts({"base":"item.ember","rarity":0}),"legacy settings without new sections retain audio and gain default input/filter")
	var restore := FileAccess.open(Settings.storage_path,FileAccess.WRITE)
	restore.store_string(original_config)
	restore.close()
	Settings.load_settings()
	Settings.storage_path = original_path

func verify_loot(session, check: Callable) -> void:
	var world: GameWorld = session.world
	world.set_physics_process(false)
	for actor in world.actors: actor.set_physics_process(false)
	world.drops.clear()
	session.inventory.items.clear()
	var generator := ItemGenerator.new()
	generator.rng.seed = 343
	for entry in [["item.ember",0,20],["item.prism",2,50],["item.relic",3,70],["item.boots",1,80]]:
		world.drop_item(world.trainer.position+Vector2(entry[2],0),generator.generate(entry[0],1,entry[1]))
	var snapshot := WorldSnapshot.capture(world)
	check.call(world.visible_drops().size()==2 and world.pickup_candidate()==1,"filter hides low rarity and chooses the nearest visible pickup")
	Settings.loot_filter.categories.held = false
	check.call(world.visible_drops().size()==1 and world.visible_drops()[0].item.base=="item.relic","unique override preserves important drops even when their category is hidden")
	Settings.loot_filter.always_unique = false
	check.call(world.visible_drops().is_empty() and world.pickup_candidate()==-1,"hidden items are excluded from normal pickup")
	check.call(WorldSnapshot.capture(world).drops==snapshot.drops,"filter settings never delete or alter saved world loot")
	Input.action_press("show_all_loot")
	world._physics_process(0)
	check.call(world.reveal_loot and world.visible_drops().size()==4 and world.pickup_candidate()==0,"holding reveal exposes filtered loot for inspection and pickup")
	world.interact()
	check.call(session.inventory.items.size()==1 and session.inventory.items[0].base=="item.ember" and world.drops.size()==3,"revealed item can actually be picked up")
	Input.action_release("show_all_loot")
	world._physics_process(0)
	check.call(not world.reveal_loot and world.visible_drops().is_empty() and world.drops.size()==3,"releasing reveal reapplies the filter without losing remaining items")
	WorldSnapshot.restore(world,snapshot)
	Settings.loot_filter.restore({"minimum_rarity":2})
	var count := world.drops.size()
	var capacity: int = session.inventory.capacity
	session.inventory.capacity = 0
	world.interact()
	check.call(world.drops.size()==count,"full inventory does not consume the selected visible drop")
	session.inventory.capacity = capacity
	world.interact()
	check.call(session.inventory.items[-1].base=="item.prism" and world.drops.size()==count-1,"normal pickup respects rarity and proximity")
	Settings.loot_filter.restore({})
	check.call(world.visible_drops().size()==world.drops.size(),"reset restores visibility of all remaining loot")
