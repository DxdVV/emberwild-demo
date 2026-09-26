extends RefCounted

func run(session, check: Callable) -> void:
	var actor: Actor = session.world.trainer
	var motion := actor.presentation.character_animation
	var origin := actor.position
	var enabled := Audio.enabled
	Audio.enabled = false
	var contacts: Array = []
	var listener := func(): contacts.append({"distance":motion.travelled,"frame":motion.previous_frame,"clip":motion.current_clip})
	motion.footfall.connect(listener)
	actor.abilities.interrupt()
	actor.dodge_time = 0
	motion.recover()
	for direction in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]:
		for hz in [30,60]:
			contacts.clear()
			motion.travelled = 0
			actor.last_direction = direction
			actor.velocity = direction*180
			motion.previous_position = actor.global_position
			for tick in hz:
				actor.position += direction*(180.0/hz)
				motion.tick(1.0/hz,false)
			check.call(contacts.size()==3 and contacts.all(func(event): return event.clip=="walk" and event.frame%6 in [0,3]),"footfalls follow grounded directional frames at %d Hz: %s"%[hz,direction])
	contacts.clear()
	# Nonzero attempted velocity with no resolved displacement (wall).
	for tick in 60: motion.tick(1.0/60,false)
	check.call(contacts.is_empty(),"pushing against a wall makes no footsteps")
	actor.velocity = Vector2.ZERO
	for tick in 60: motion.tick(1.0/60,false)
	check.call(contacts.is_empty(),"standing idle makes no footsteps")
	actor.velocity = Vector2(180,0)
	actor.position.x += 600
	motion.tick(1.0/60,false)
	check.call(contacts.is_empty(),"teleport cannot emit a burst of catch-up footsteps")
	actor.dodge_time = .2
	for tick in 20:
		actor.position.x += 3
		motion.tick(1.0/60,false)
	check.call(contacts.is_empty(),"dodge motion suppresses foot contacts even at walking speed")
	actor.dodge_time = 0
	actor.abilities.phase = AbilityController.Phase.WINDUP
	motion.travelled = 0
	for tick in 40:
		actor.position.x += 3
		motion.tick(1.0/60,false)
	check.call(contacts.size()==2,"moving casts retain foot contact audio")
	contacts.clear()
	motion.fall()
	for tick in 70: motion.tick(1.0/60,false)
	check.call(contacts.is_empty(),"defeat presentation never emits footsteps")
	actor.abilities.interrupt()
	actor.position = origin
	actor.velocity = Vector2.ZERO
	motion.recover()
	check.call(contacts.is_empty() and motion.travelled==0,"recovery resets gait without a phantom step")
	motion.footfall.disconnect(listener)
	Audio.enabled = enabled
	var old_rng := Audio.rng.state
	var old_samples := Audio.last_sample.duplicate()
	Audio.rng.seed = 372
	Audio.last_sample.clear()
	var seen := {}
	var previous: AudioStream
	var repeats := false
	for attempt in 60:
		var sample := Audio.choose_sample("footstep")
		repeats = repeats or sample==previous
		previous = sample
		seen[sample.resource_path] = true
	check.call(seen.size()==3 and not repeats,"three footstep samples vary without immediate repetition")
	check.call(Audio.sound_cache.footstep.all(func(sample): return sample is AudioStreamWAV and sample.get_length()>.1 and sample.get_length()<.2),"all footstep variants are imported short PCM samples")
	check.call(Audio.choose_sample("hit")==Audio.sound_cache.hit[0],"existing single-sample cues retain their stream")
	check.call(Audio.choose_sample("unknown")==null,"unknown audio cue has no sample")
	Audio.rng.state = old_rng
	Audio.last_sample = old_samples
