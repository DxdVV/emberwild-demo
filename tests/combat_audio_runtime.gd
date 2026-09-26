extends Node

var session
var failures: int = 0
var checks: int = 0
var report: Array = []

func _ready() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print("COMBAT AUDIO ",label," verified=",value)

func heard(samples: Array[AudioStream], at: Vector2, gain: float) -> bool:
	return Audio.spatial_voices.any(func(voice): return voice.playing and voice.stream in samples and voice.bus=="SFX" and voice.global_position==at and voice.volume_db==gain)

func run() -> void:
	preload("res://tests/combat_audio_checks.gd").new().run(check)
	session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	session.hud.close_panel()
	session.autosave_remaining = 100000
	for actor in session.world.actors: actor.set_physics_process(false)
	session.world.set_physics_process(false)
	var source: Actor = session.world.trainer
	source.position = Vector2(470,510)
	source.presentation.recover()
	session.world.camera.snap(source.position)
	var target: Actor = session.world.spawn_actor("species.briar",Factions.Team.WILD,source.position+Vector2(100,0))
	target.set_physics_process(false)
	for id in ["pulse","spark","splash","thorn","arc","slam","flare","tide","roots","storm","breath","frost","sweep","discharge"]:
		var ability: AbilityData = Database.abilities["ability."+id]
		var profile := ability.audio_profile
		var cast_key := "ability:"+str(profile.id)+":cast"
		var impact_key := "ability:"+str(profile.id)+":impact"
		for key in [cast_key,impact_key]:
			Audio.sound_cache.erase(key)
			Audio.last_played.erase(key)
		for voice in Audio.spatial_voices: voice.stop()
		source.abilities.interrupt()
		source.combat.rest()
		target.statuses.clear()
		target.health.reset(10000)
		target.health.invulnerable = 0
		session.hud.notify(tr(ability.name_key))
		check(source.abilities.cast(str(ability.id),target) and not Audio.sound_cache.has(cast_key),"windup is silent before actual release: "+id)
		var cast_heard := false
		var impact_heard := false
		for tick in 120 if id=="slam" else 75:
			source.abilities.tick(1.0/60)
			source.presentation.tick(1.0/60)
			target.presentation.tick(1.0/60)
			cast_heard = cast_heard or heard(profile.cast_samples,source.global_position,profile.cast_gain_db)
			impact_heard = impact_heard or heard(profile.impact_samples,target.global_position,profile.impact_gain_db)
			await get_tree().physics_frame
		check(Audio.sound_cache.has(cast_key),"actual release routes cast profile: "+id)
		check(target.health.current<10000 and Audio.sound_cache.has(impact_key),"actual damage routes impact profile: "+id)
		if Audio.enabled: check(cast_heard and impact_heard,"native cast/impact streams, positions and gains: "+id)
		report.append({"ability":id,"cast":cast_heard,"impact":impact_heard})
	var pulse: AbilityData = Database.abilities["ability.pulse"]
	var key := "ability:lantern:impact"
	Audio.sound_cache.erase(key)
	target.health.invulnerable = 1
	session.world.damage.apply(source,target,pulse)
	check(not Audio.sound_cache.has(key),"invulnerability does not emit a hit sound")
	target.health.invulnerable = 0
	target.health.shield = 1000
	var before := target.health.current
	session.world.damage.apply(source,target,pulse)
	check(target.health.current==before and Audio.sound_cache.has(key),"fully absorbed hit still emits contact feedback")
	# A cancelled attack never reaches the world launch hook.
	Audio.sound_cache.erase("ability:lantern:cast")
	source.combat.rest()
	source.abilities.interrupt()
	source.abilities.cast("ability.pulse",target)
	source.abilities.interrupt()
	source.abilities.tick(1)
	check(not Audio.sound_cache.has("ability:lantern:cast"),"interrupted windup cannot play a release")
	Audio.sound_cache.erase("ability:heavy:impact")
	Audio.last_played.erase("ability:heavy:impact")
	var hazard := GroundHazard.new()
	hazard.world = session.world
	hazard.source_ref = weakref(source)
	hazard.position = source.position+Vector2(0,150)
	hazard.duration = .25
	session.world.add_child(hazard)
	hazard.set_physics_process(false)
	hazard.advance(.2)
	check(not Audio.sound_cache.has("ability:heavy:impact"),"ground warning stays silent before impact")
	hazard.advance(.05)
	check(Audio.sound_cache.has("ability:heavy:impact"),"heavy ground impact sounds even without a victim")
	if Audio.enabled:
		check(heard(Database.abilities["ability.slam"].audio_profile.impact_samples,hazard.global_position,-4),"native heavy impact is positioned at the ground strike")
		for voice in Audio.spatial_voices: voice.stop()
		Audio.last_played.erase("ability:fire:impact")
		for attempt in 50: Audio.play_ability(Database.abilities["ability.spark"],"impact",target.global_position)
		check(Audio.spatial_voices.filter(func(voice): return voice.playing).size()==1,"same-profile crowd hits coalesce into one immediate voice")
	hazard.queue_free()
	check(Audio.spatial_voices.size()<=Audio.VOICE_LIMIT,"new profiles retain bounded spatial voices")
	var output := FileAccess.open("res://build/combat-audio-runtime.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks":checks,"failures":failures,"native":Audio.enabled,"abilities":report},"\t"))
	output.close()
	Audio.shutdown()
	for tick in 4: await get_tree().process_frame
	print("COMBAT AUDIO RUNTIME checks=",checks," verified=",failures==0)
	get_tree().quit(0 if failures==0 else 1)
