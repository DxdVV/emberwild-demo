extends Node

var session
var results: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	results.append({"check":label,"success":condition})
	print("COMBAT READABILITY ",condition," ",label)

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/combat-readability-"+label+".png")

func freeze() -> void:
	session.world.set_physics_process(false)
	for actor in session.world.actors: actor.set_physics_process(false)

func run() -> void:
	session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	session.autosave_remaining = 100000
	session.hud.close_panel(true)
	session.change_area("area.grove",false)
	var world: GameWorld = session.world
	for actor in world.actors.duplicate():
		if Factions.hostile(Factions.Team.TRAINER,actor.faction): world.remove_actor(actor)
	world.trainer.position = Vector2(1190,1000)
	for actor in session.party.active_actors: actor.position = world.trainer.position
	var boss := world.spawn_actor("species.guardian",Factions.Team.BOSS,world.trainer.position+Vector2(0,25))
	world.focus_target = boss
	freeze()
	world.camera.cinematic = true
	world.camera.snap(Vector2(1190,950))
	var markers: CombatMarkers = world.combat_markers
	var quality: int = Settings.effects_quality
	Settings.effects_quality = 0
	Settings.changed.emit()
	markers.refresh()
	check(markers.markers.size()==4,"overlapped trainer, both slots and focus all receive markers at low effect quality")
	var separate := true
	for first in markers.markers.size():
		for second in range(first+1,markers.markers.size()):
			separate = separate and not markers.markers[first].rect.intersects(markers.markers[second].rect)
	check(separate,"coincident companion glyphs do not overlap")
	check(markers.z_index>world.effects.z_index and markers.z_index>world.entity_layer.z_index,"identity markers render above actor bodies and decorative effects")
	check(markers.material.light_mode==CanvasItemMaterial.LIGHT_MODE_UNSHADED,"local light cannot wash out identity glyphs")
	var before: Dictionary = session.save_data().duplicate(true)
	var random_state: int = world.damage.rng.state
	check(not markers.refresh() and session.save_data()==before and world.damage.rng.state==random_state,"unchanged overlay skips redraw without changing combat state or RNG")
	world.hazard(boss,world.trainer.position,95,1.1)
	var hazard: GroundHazard = world.hazards.back()
	hazard.set_physics_process(false)
	hazard.elapsed = .7
	hazard.queue_redraw()
	check(hazard.material.light_mode==CanvasItemMaterial.LIGHT_MODE_UNSHADED and not hazard.activated,"critical ground warning remains visible before damage at low effects")
	await capture("overlap-low")
	world.trainer.position += Vector2(-150,60)
	session.party.active_actors[0].position += Vector2(-95,-40)
	session.party.active_actors[1].position += Vector2(105,-30)
	check(markers.refresh(),"moving actors refresh the same bounded marker layer")
	await capture("separated")
	var first_id: String = session.party.active_actors[0].identity
	session.party.swap_remaining = 0
	check(session.party.swap(2,0),"real party replacement succeeds")
	freeze()
	markers.refresh()
	check(markers.markers.any(func(entry): return entry.kind=="1" and entry.id==session.party.active_actors[0].identity) and not markers.markers.any(func(entry): return entry.id==first_id),"slot one moves to the replacement and removes old actor identity")
	session.hud.refresh_party_cards()
	var card = session.hud.companion_row.get_child(0)
	check(card.get_child(1).get_child(0).text.begins_with("1 · "),"HUD card uses the same permanent slot number as its world marker")
	await capture("swapped")
	var old_count := markers.markers.size()
	world.remove_actor(boss)
	markers.refresh()
	check(markers.markers.size()==old_count-1 and not markers.markers.any(func(entry): return entry.kind=="focus"),"removed focus cannot leave a stale target marker")
	world.trainer.health.current = 0
	get_tree().paused = true
	for frame in 2: await get_tree().process_frame
	check(not markers.markers.any(func(entry): return entry.kind=="player"),"trainer marker clears even while defeat pauses the world")
	get_tree().paused = false
	world.trainer.health.current = world.trainer.health.maximum
	var old_layer: WeakRef = weakref(markers)
	session.change_area("area.haven",false)
	freeze()
	for frame in 3: await get_tree().process_frame
	check(old_layer.get_ref()==null and session.world.combat_markers.markers.size()==3,"area replacement frees the old layer and binds only the current team")
	Settings.effects_quality = quality
	Settings.changed.emit()
	Audio.shutdown()
	for frame in 5: await get_tree().process_frame
	var passed := results.all(func(result): return result.success)
	var report := FileAccess.open("res://build/combat-readability.json",FileAccess.WRITE)
	report.store_string(JSON.stringify(results,"\t"))
	report.close()
	print("COMBAT READABILITY RUNTIME verified=",passed)
	get_tree().quit(0 if passed else 1)
