extends Node

var session
var labels: WorldLabels
var tooltip: ContextTooltip
var failed: bool = false
var game_viewport: SubViewport

func _ready() -> void: run.call_deferred()

func verify(value: bool, message: String) -> void:
	print("GROUND TOOLTIP ",message," verified=",value)
	if not value:
		failed = true
		print("GROUND TOOLTIP state dirty=",labels.dirty," reserved_dirty=",labels.reserved_dirty," regions=",labels.drop_regions.size()," hover=",labels.hovered_index," keyboard=",tooltip.keyboard," elapsed=",tooltip.elapsed," gui=",game_viewport.gui_get_hovered_control())
		print("GROUND TOOLTIP pointer=",labels.get_local_mouse_position()," first_rect=",labels.drop_regions[0].rect if not labels.drop_regions.is_empty() else Rect2()," focused=",get_window().has_focus())

func settle(amount: int = 40) -> void:
	for index in amount: await get_tree().process_frame

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.window_id = get_window().get_window_id()
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	game_viewport.push_input(event,true)

func point(at: Vector2, frames: int = 40) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	game_viewport.push_input(event,true)
	await settle(frames)

func region(index: int) -> Rect2:
	for entry in labels.drop_regions:
		if entry.index==index: return entry.rect
	return Rect2()

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	game_viewport.get_texture().get_image().save_png("res://build/ground-tooltip-"+label+".png")

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Ground-label input requires a rendered frame; use the headless ownership checks separately.")
		get_tree().quit(1)
		return
	# A dedicated rendered viewport receives real GUI events without warping the
	# desktop pointer or letting unrelated OS mouse motion change the test target.
	game_viewport = SubViewport.new()
	game_viewport.size = Vector2i(960,540)
	game_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	game_viewport.gui_embed_subwindows = true
	add_child(game_viewport)
	var preview := TextureRect.new()
	preview.texture = game_viewport.get_texture()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(preview)
	var old_filter := Settings.loot_filter.to_dict()
	var old_bindings: Dictionary = Settings.inputs.bindings.duplicate(true)
	var old_locale: String = Settings.locale
	Settings.inputs.reset()
	Settings.loot_filter.restore({})
	Settings.set_locale("ru",false)
	session = load("res://scenes/main.tscn").instantiate()
	game_viewport.add_child(session)
	session.autosave_remaining = 100000
	session.hud.close_panel(true)
	session.change_area("area.grove",false)
	var world: GameWorld = session.world
	for actor in world.actors.duplicate():
		if Factions.hostile(actor.faction,Factions.Team.TRAINER): world.remove_actor(actor)
		else: actor.set_physics_process(false)
	world.trainer.position = Vector2(1190,1000)
	world.camera.snap(world.trainer.position)
	world.camera.set_physics_process(false)
	for index in session.party.active_actors.size(): session.party.active_actors[index].position = world.trainer.position+Vector2(-45+90*index,50)
	labels = session.hud.world_labels
	tooltip = session.hud.context_tooltip
	world.drops.clear()
	for offset in [Vector2(15,40),Vector2(175,75),Vector2(110,-75)]:
		world.drop_item(world.trainer.position+offset,world.item_generator.generate("item.ember",3,2))
	await settle(8)
	verify(labels.drop_regions.size()==3,"only rendered drop labels expose hit rectangles")
	var first: Dictionary = world.drops[0].item
	var first_rect := region(0)
	var rng_before: int = world.item_generator.rng.state
	await point(first_rect.get_center())
	verify(tooltip.visible and tooltip.description.text==TooltipPresenter.item_summary(first),"mouse hover describes exact ground-item affixes")
	verify(world.drops.size()==3 and world.item_generator.rng.state==rng_before,"inspection preserves drops and loot RNG")
	await capture("item")
	await point(region(1).get_center(),10)
	verify(not tooltip.visible,"moving between identical-name items restarts hover delay")
	await settle()
	verify(tooltip.visible and tooltip.description.text==TooltipPresenter.item_summary(world.drops[1].item),"second same-name item uses its own modifiers")
	await capture("second")
	await point(first_rect.get_center())
	Settings.loot_filter.restore({"minimum_rarity":3})
	Settings.changed.emit()
	await settle()
	verify(labels.drop_regions.is_empty() and not tooltip.visible and not labels.hover_control.visible,"filter removes hidden ground hit targets and open tooltip")
	key(KEY_ALT,true)
	await settle()
	verify(world.reveal_loot and tooltip.visible and tooltip.description.text==TooltipPresenter.item_summary(first),"held reveal restores hover under a stationary mouse")
	await capture("revealed")
	key(KEY_ALT,false)
	await settle()
	verify(not world.reveal_loot and not tooltip.visible,"releasing reveal clears filtered item description")
	Settings.loot_filter.restore({})
	Settings.changed.emit()
	await settle(8)
	await point(region(0).get_center())
	key(KEY_I,true)
	await settle(4)
	key(KEY_I,false)
	verify(get_tree().paused and session.hud.panel.visible and not tooltip.visible,"hover does not consume inventory key and modal hides ground description")
	session.hud.close_panel(true)
	await point(region(0).get_center())
	key(KEY_R,true)
	await settle(4)
	key(KEY_R,false)
	await settle()
	verify(world.drops.size()==2 and session.inventory.items.any(func(item): return item.id==first.id),"real interaction key picks the nearest item while hovered")
	verify(not tooltip.visible and labels.hover_description().is_empty(),"picked item cannot leave its previous affixes on screen")
	await capture("picked")
	await point(region(0).get_center())
	world.trainer.set_physics_process(true)
	world.camera.set_physics_process(true)
	var start := world.trainer.position
	key(KEY_D,true)
	await settle(12)
	key(KEY_D,false)
	world.trainer.set_physics_process(false)
	verify(world.trainer.position.distance_to(start)>5,"ground hover does not stop actual keyboard movement")
	world.trainer.position += Vector2(260,100)
	world.camera.snap(world.trainer.position)
	await settle()
	verify(not tooltip.visible,"camera displacement discards the old label hit location")
	for index in 120:
		world.drops.append({"at":world.trainer.position+Vector2(index%15*35-245,(index/15)*30-105),"item":world.item_generator.generate("item.ember",3,index%4)})
	world.refresh_labels()
	await settle(8)
	verify(labels.drop_regions.size()<=64 and labels.drop_regions.size()>10 and labels.get_child_count()==1,"dense loot reuses one hover control for the bounded rendered labels")
	# Pointing changes camera look-ahead; hold it for this exact-rectangle density case.
	# Actual movement and changed camera coordinates are exercised above.
	world.camera.set_physics_process(false)
	await settle(3)
	var hit: Dictionary = labels.drop_regions[0]
	await point(hit.rect.get_center())
	verify(tooltip.visible and tooltip.description.text==TooltipPresenter.item_summary(hit.item),"dense-label hover resolves the visible item's identity")
	await capture("dense")
	Settings.set_locale("en",false)
	await settle(8)
	await point(labels.drop_regions[0].rect.get_center())
	verify(tooltip.visible and tooltip.description.text==TooltipPresenter.item_summary(labels.drop_regions[0].item),"English ground label and description share current item data")
	await capture("english")
	session.change_area("area.haven",false)
	await settle()
	verify(labels.hover_description().is_empty() and not tooltip.visible,"area replacement clears old world-item inspection")
	Settings.inputs.restore(old_bindings)
	Settings.loot_filter.restore(old_filter)
	Settings.set_locale(old_locale,false)
	Settings.changed.emit()
	Audio.shutdown()
	await settle(5)
	print("GROUND TOOLTIP RENDER COMPLETE verified=",not failed)
	get_tree().quit(1 if failed else 0)
