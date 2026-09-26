extends Node

var rng := RandomNumberGenerator.new()
var music: AudioStreamPlayer
var ambience: AudioStreamPlayer
var sound_cache: Dictionary = {}
var enabled: bool = true
var spatial_root: WeakRef
var spatial_voices: Array[AudioStreamPlayer2D] = []
var last_played: Dictionary = {}
var last_sample: Dictionary = {}
const VOICE_LIMIT := 24

func bind_world(world: Node2D) -> void:
	spatial_root = weakref(world)
	spatial_voices.clear()
	last_played.clear()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = DisplayServer.get_name() != "headless"
	rng.randomize()
	for bus in ["Music","SFX","UI","Ambience","Voice"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
	apply_settings()
	Settings.changed.connect(apply_settings)
	for id in ["cast","hit","capture","ui","dodge","loot"]: sound_cache[id] = [load("res://assets/audio/"+id+".wav")]
	sound_cache["footstep"] = []
	for index in range(1,4): sound_cache["footstep"].append(load("res://assets/audio/footstep-%d.wav"%index))
	if enabled:
		music = loop_player("music","Music")
		ambience = loop_player("ambience","Ambience")

func loop_player(file: String, bus: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = load("res://assets/audio/"+file+".wav")
	player.bus = bus
	add_child(player)
	player.finished.connect(player.play)
	player.play()
	return player

func apply_settings() -> void:
	for bus in Settings.volumes:
		var index := AudioServer.get_bus_index(bus)
		if index >= 0: AudioServer.set_bus_volume_db(index,linear_to_db(Settings.volumes[bus]))

func choose_sample(id: String) -> AudioStream:
	var samples: Array = sound_cache.get(id,[])
	if samples.is_empty(): return null
	var index := 0
	if samples.size()>1:
		var previous := int(last_sample.get(id,-1))
		index = rng.randi_range(0,samples.size()-2 if previous>=0 else samples.size()-1)
		if previous>=0 and index>=previous: index += 1
	last_sample[id] = index
	return samples[index]

func play_ability(ability: AbilityData, phase: String, at: Vector2) -> void:
	if phase not in ["cast","impact"]: return
	var profile := ability.audio_profile
	if profile==null:
		play("cast" if phase=="cast" else "hit",at)
		return
	var id := "ability:"+str(profile.id)+":"+phase
	sound_cache[id] = profile.cast_samples if phase=="cast" else profile.impact_samples
	play(id,at,profile.cast_gain_db if phase=="cast" else profile.impact_gain_db)

func play(id: String, at: Vector2 = Vector2.INF, gain_db: float = 0) -> void:
	if not enabled: return
	if not sound_cache.has(id): return
	if at == Vector2.INF:
		var player := AudioStreamPlayer.new()
		player.stream = choose_sample(id)
		player.bus = "UI"
		player.volume_db = gain_db
		player.pitch_scale = rng.randf_range(.94,1.06)
		add_child(player)
		player.finished.connect(player.queue_free)
		player.play()
	else:
		var world = spatial_root.get_ref() if spatial_root != null else null
		if not is_instance_valid(world): return
		var now := Time.get_ticks_msec()
		if now-int(last_played.get(id,-1000))<28: return
		last_played[id] = now
		var player: AudioStreamPlayer2D
		for voice in spatial_voices:
			if is_instance_valid(voice) and not voice.playing:
				player = voice
				break
		if player==null:
			if spatial_voices.size()>=VOICE_LIMIT: return
			player = AudioStreamPlayer2D.new()
			world.add_child(player)
			spatial_voices.append(player)
		player.stream = choose_sample(id)
		player.bus = "SFX"
		# Reset on every reuse; a quiet footstep must not attenuate the next hit.
		player.volume_db = -10.0 if id=="footstep" else gain_db
		player.max_distance = 900
		player.global_position = at
		player.pitch_scale = rng.randf_range(.9,1.1)
		player.play()

func duck(active: bool) -> void:
	if is_instance_valid(music): create_tween().tween_property(music,"volume_db",-8.0 if active else 0.0,.3)

func shutdown() -> void:
	for player in [music,ambience]:
		if is_instance_valid(player):
			if player.finished.is_connected(player.play): player.finished.disconnect(player.play)
			player.stop()
			player.stream = null
	for voice in spatial_voices:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null

func _exit_tree() -> void: shutdown()
