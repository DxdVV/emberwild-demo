extends Node2D

var world: GameWorld
var hud: GameHUD
var party := PartySystem.new()
var inventory := InventoryData.new()
var stash := InventoryData.new()
var equipment: Dictionary = {}
var quest: Dictionary = {"capture":false,"elite":false,"boss":false}
var seed_value: int = 48371
var combat_damage: float = 0
var combat_events: int = 0
var transitioning: bool = false
var autosave_remaining: float = 60
var generation: int = 1
var world_states: Dictionary = {}
var trainer_combat: CombatState
var screenshot_path: String = ""
var world_viewport: SubViewport
var world_container: SubViewportContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	get_window().close_requested.connect(request_exit)
	stash.capacity = 100
	world_container = SubViewportContainer.new()
	world_container.name = "WorldPixelViewport"
	world_container.stretch = true
	world_container.stretch_shrink = 2
	world_container.size = Vector2(960,540)
	world_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(world_container)
	world_viewport = SubViewport.new()
	world_viewport.size = Vector2i(480,270)
	world_viewport.disable_3d = true
	world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world_viewport.audio_listener_enable_2d = true
	world_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	world_viewport.snap_2d_transforms_to_pixel = true
	world_container.add_child(world_viewport)
	new_journey()
	hud = GameHUD.new()
	hud.session = self
	add_child(hud)
	change_area("area.haven",false)
	var args := OS.get_cmdline_user_args()
	if "--autostart" in args:
		hud.close_panel()
	else: hud.show_title()
	if "--grove" in args: change_area("area.grove",false)
	if "--resolution-640" in args: get_window().content_scale_size = Vector2i(640,360)
	for arg in args:
		if arg.begins_with("--screenshot="): screenshot_path = arg.trim_prefix("--screenshot=")
	if not screenshot_path.is_empty(): capture_frame.call_deferred()

func new_journey() -> void:
	if is_instance_valid(world):
		world_viewport.remove_child(world)
		world.queue_free()
		world = null
	trainer_combat = null
	party.roster.clear()
	party.active_indices = [0,1]
	party.active_actors.clear()
	party.swap_remaining = 0
	party.mode = ActorBrain.Mode.AGGRESSIVE
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for id in ["species.cinder","species.rill","species.volt"]: party.add(CreatureInstance.create(Database.species[id],rng))
	inventory = InventoryData.new()
	stash = InventoryData.new()
	stash.capacity = 100
	equipment.clear()
	world_states.clear()
	quest = {"capture":false,"elite":false,"boss":false}
	var generator := ItemGenerator.new()
	generator.identity_scope = "starter"
	generator.rng.seed = seed_value
	inventory.add(generator.generate("item.prism",1,2))
	inventory.add(generator.generate("item.seed",1,1))
	inventory.add(generator.generate("item.boots",1,1))

func change_area(id: String, fade: bool = true, arrival: Dictionary = {}) -> void:
	if transitioning or not Database.areas.has(id): return
	transitioning = true
	if fade and is_instance_valid(hud): await hud.fade(true)
	if is_instance_valid(world):
		world_states[str(world.area.id)] = WorldSnapshot.capture(world)
		world_viewport.remove_child(world)
		world.queue_free()
	world = GameWorld.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.session = self
	world.area = Database.areas[id]
	world.seed_value = seed_value+generation
	world.arrival = arrival
	world.message.connect(hud.notify)
	world.exit_requested.connect(change_area)
	world.trainer_defeated.connect(hud.show_defeat)
	world_viewport.add_child(world)
	hud.bind_world()
	if fade: await hud.fade(false)
	transitioning = false

func _process(delta: float) -> void:
	if is_instance_valid(world) and not get_tree().paused:
		autosave_remaining -= delta
		if autosave_remaining<=0:
			autosave_remaining = 60
			save_game(false)
	if not Settings.input_blocked():
		if Input.is_action_just_pressed("save_game",true): save_game()
		if Input.is_action_just_pressed("load_game",true): load_game()

func _unhandled_input(event: InputEvent) -> void:
	if Settings.input_blocked(): return
	if is_instance_valid(world) and world.trainer.health.current<=0:
		hud.show_defeat()
		return
	var escape: bool = event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode==KEY_ESCAPE or event.keycode==KEY_ESCAPE)
	if escape or event.is_action_pressed("pause",false,true):
		if hud.panel.visible: hud.close_panel()
		else: hud.show_pause()
	elif event.is_action_pressed("inventory",false,true): hud.show_inventory()
	elif event.is_action_pressed("party",false,true): hud.show_party()
	elif event.is_action_pressed("debug_menu",false,true) and OS.is_debug_build(): hud.show_debug()

func demo_completed() -> bool:
	return quest.get("capture",false) and quest.get("elite",false) and quest.get("boss",false)

func open_camp() -> void:
	if demo_completed(): hud.show_demo_complete(true)
	else: hud.show_camp()

func save_data() -> Dictionary:
	world_states[str(world.area.id)] = WorldSnapshot.capture(world)
	var roster: Array = []
	for creature in party.roster: roster.append(creature.to_dict())
	return {"party":roster,"active":party.active_indices,"party_state":{"swap_remaining":party.swap_remaining,"mode":party.mode,"placements":party.placements()},"inventory":inventory.to_dict(),"stash":stash.to_dict(),"equipment":equipment.duplicate(true),"quest":quest.duplicate(),"seed":seed_value,"generation":generation,"world_states":world_states.duplicate(true),"area":str(world.area.id),"trainer":{"health":world.trainer.health.current,"combat":trainer_combat.to_dict(),"position":[world.trainer.position.x,world.trainer.position.y],"direction":[world.trainer.last_direction.x,world.trainer.last_direction.y]}}

func save_game(show_notice: bool = true) -> bool:
	if not is_instance_valid(world): return false
	var success := SaveStore.write(save_data(),"",SavedJourney.valid)
	if show_notice or not success: hud.notify(tr("notice.saved") if success else SaveStore.last_error)
	return success

func request_exit() -> bool:
	if not save_game(false):
		hud.show_pause()
		hud.notify(tr("save.exit_failed")+"\n"+SaveStore.last_error)
		return false
	get_tree().quit()
	return true

func load_game(path: String = "") -> bool:
	if transitioning:
		hud.notify(tr("save.travel_busy"))
		return false
	var data := SaveStore.read_save(path,SavedJourney.valid)
	if data.is_empty(): hud.notify(SaveStore.last_error if not SaveStore.last_error.is_empty() else tr("notice.missing_save")) ; return false
	var loaded: Array[CreatureInstance] = []
	var identities: Dictionary = {}
	for entry in data.get("party",[]):
		if not entry is Dictionary or not Database.species.has(entry.get("species","")): continue
		var creature := CreatureInstance.from_dict(entry)
		if creature.persistent_id.is_empty() or identities.has(creature.persistent_id): continue
		identities[creature.persistent_id] = true
		loaded.append(creature)
	if loaded.is_empty(): hud.notify(tr("notice.empty_party")) ; return false
	party.roster = loaded
	party.active_indices.clear()
	for index in data.get("active",[0]):
		if index>=0 and index<loaded.size() and index not in party.active_indices and party.active_indices.size()<Database.rules.active_limit: party.active_indices.append(int(index))
	if party.active_indices.is_empty(): party.active_indices.append(0)
	party.swap_remaining = float(data.get("party_state",{}).get("swap_remaining",0))
	party.mode = clampi(int(data.get("party_state",{}).get("mode",0)),0,3) as ActorBrain.Mode
	inventory.restore(data.get("inventory",{}))
	stash.restore(data.get("stash",{}))
	equipment = data.get("equipment",{}).duplicate(true)
	quest = data.get("quest",{}).duplicate()
	seed_value = int(data.get("seed",48371))
	generation = int(data.get("generation",1))
	# Discard the current runtime before loading so it cannot overwrite saved world state.
	if is_instance_valid(world):
		world_viewport.remove_child(world)
		world.queue_free()
		world = null
	trainer_combat = null
	world_states = data.get("world_states",{}).duplicate(true)
	hud.close_panel(true)
	var area_id := str(data.get("area","area.haven"))
	var trainer_data: Dictionary = data.get("trainer",{})
	change_area(area_id,false,{"trainer":trainer_data,"companions":data.get("party_state",{}).get("placements",{})})
	if world.trainer.health.current<=0: world.trainer.on_defeated()
	world.camera.snap(world.trainer.position)
	hud.notify(tr("save.recovered") if SaveStore.recovered_backup else tr("notice.loaded"))
	return true

func equip(index: int, creature_index: int = 0) -> void:
	if index<0 or index>=inventory.items.size(): return
	var item := inventory.items[index]
	var definition: ItemData = Database.items[item.base]
	var previous: Dictionary = {}
	if definition.category == &"held":
		if creature_index<0 or creature_index>=party.roster.size(): return
		previous = party.roster[creature_index].held_item
		var incoming := inventory.exchange(index,previous,false)
		if incoming.is_empty(): return
		party.roster[creature_index].held_item = incoming
		var state := party.roster[creature_index].ensure_combat()
		var ratio := state.health.current/state.health.maximum
		state.apply_held_item(party.roster[creature_index].held_item)
		state.health.reset(state.stats.value("health"),ratio)
		party.roster[creature_index].sync_health()
	else:
		previous = equipment.get(str(definition.slot),{})
		var incoming := inventory.exchange(index,previous,false)
		if incoming.is_empty(): return
		equipment[str(definition.slot)] = incoming
		world.apply_trainer_equipment()
	inventory.changed.emit()
	hud.notify(tr("notice.equipped")%tr(definition.name_key))

func revive() -> void:
	party.rest()
	trainer_combat.rest()
	hud.close_panel(true)
	change_area("area.haven",false)

func unequip_held(index: int) -> bool:
	if index<0 or index>=party.roster.size(): return false
	var creature: CreatureInstance = party.roster[index]
	if creature.held_item.is_empty() or not inventory.add(creature.held_item,false): return false
	var state := creature.ensure_combat()
	var ratio := state.health.current/state.health.maximum
	creature.held_item = {}
	state.apply_held_item({})
	state.health.reset(state.stats.value("health"),ratio)
	creature.sync_health()
	inventory.changed.emit()
	return true

func unequip_trainer(slot: String) -> bool:
	if not equipment.has(slot) or not inventory.add(equipment[slot],false): return false
	equipment.erase(slot)
	world.trainer.stats.remove_source("equipment:"+slot)
	world.trainer.triggers.set_source("equipment:"+slot,[])
	world.trainer.combat.ability_modifier_sources.erase("equipment:"+slot)
	world.apply_trainer_equipment()
	inventory.changed.emit()
	return true

func new_expedition() -> void:
	generation += 1
	# Preserve the haven snapshot while explicitly rerolling the adventure area.
	world_states.erase("area.grove")
	hud.close_panel()
	change_area("area.grove")

func capture_frame() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(screenshot_path)
	print("SCREENSHOT ",screenshot_path," result=",error," debug=",OS.is_debug_build()," area=",world.area.id)
	get_tree().quit(0 if error==OK else 1)
