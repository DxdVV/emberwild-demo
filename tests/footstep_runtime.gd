extends Node

var failures: int = 0
var checks: int = 0
var contacts: Array = []
var session

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print("FOOTSTEPS ",label," verified=",value)

func ticks(count: int) -> void:
	for tick in count: await get_tree().physics_frame

func run() -> void:
	session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	session.hud.close_panel()
	session.autosave_remaining = 100000
	var actor: Actor = session.world.trainer
	for member in session.world.actors: member.set_physics_process(false)
	preload("res://tests/footstep_checks.gd").new().run(session,check)
	actor.position = Vector2(430,510)
	actor.presentation.recover()
	session.world.camera.snap(actor.position)
	actor.presentation.character_animation.footfall.connect(record_contact)
	actor.set_physics_process(true)
	Input.action_press("move_right")
	await ticks(80)
	Input.action_release("move_right")
	await ticks(2)
	check(contacts.size()>=3,"real movement input emits repeated contacts")
	check(contacts.all(func(event): return event.frame%6 in [0,3]),"runtime contact callbacks see planted walk poses")
	var before := contacts.size()
	await ticks(30)
	check(contacts.size()==before,"released movement input stops contact audio")
	get_tree().paused = true
	Input.action_press("move_left")
	await ticks(30)
	check(contacts.size()==before,"paused gameplay cannot advance footsteps")
	get_tree().paused = false
	await ticks(80)
	Input.action_release("move_left")
	await ticks(2)
	check(contacts.size()>before,"resumed gameplay restores footsteps")
	if Audio.enabled:
		check(contacts.all(func(event): return event.audible),"native contacts start a positional SFX voice with the quiet footstep gain")
		for voice in Audio.spatial_voices: voice.stop()
		Audio.last_played.erase("hit")
		Audio.play("hit",actor.global_position)
		check(Audio.spatial_voices.any(func(voice): return voice.playing and voice.stream==Audio.sound_cache.hit[0] and voice.volume_db==0),"pooled hit voice resets footstep attenuation")
	var report := {"checks":checks,"failures":failures,"native":Audio.enabled,"contacts":contacts}
	var output := FileAccess.open("res://build/footsteps-runtime.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"))
	output.close()
	Audio.shutdown()
	await ticks(4)
	print("FOOTSTEPS RUNTIME checks=",checks," verified=",failures==0)
	get_tree().quit(0 if failures==0 else 1)

func record_contact() -> void:
	var actor: Actor = session.world.trainer
	contacts.append({"frame":actor.presentation.character_animation.previous_frame,"at":[actor.position.x,actor.position.y],"audible":Audio.spatial_voices.any(func(voice): return voice.playing and voice.stream in Audio.sound_cache.footstep and voice.bus=="SFX" and voice.volume_db==-10 and voice.global_position==actor.global_position)})
