extends RefCounted

func run(check: Callable) -> void:
	var profiles := {}
	for ability: AbilityData in Database.abilities.values():
		check.call(ability.audio_profile!=null and ability.audio_profile.validate().is_empty(),"ability has a valid authored audio profile: "+str(ability.id))
		if ability.audio_profile!=null: profiles[ability.audio_profile.id] = ability.audio_profile
	check.call(profiles.size()==6,"slice has six distinct combat sound profiles")
	var enabled := Audio.enabled
	var rng_state := Audio.rng.state
	var samples := Audio.last_sample.duplicate()
	Audio.enabled = false
	for profile: AbilityAudioData in profiles.values():
		var ability := AbilityData.new()
		ability.audio_profile = profile
		for phase in ["cast","impact"]:
			Audio.play_ability(ability,phase,Vector2.ZERO)
			var key: String = "ability:"+str(profile.id)+":"+phase
			var previous: AudioStream
			var seen := {}
			var repeated := false
			for attempt in 40:
				var stream := Audio.choose_sample(key)
				repeated = repeated or stream==previous
				previous = stream
				seen[stream.resource_path] = true
			check.call(seen.size()==3 and not repeated,"combat samples vary without immediate repetition: "+key)
	var invalid: AbilityAudioData = profiles.values()[0].duplicate()
	invalid.cast_gain_db = NAN
	check.call(not invalid.validate().is_empty(),"audio validation rejects nonfinite gain")
	invalid.cast_gain_db = -4
	invalid.impact_samples = [null]
	check.call(not invalid.validate().is_empty(),"audio validation rejects missing impact stream")
	invalid.impact_samples = []
	check.call(not invalid.validate().is_empty(),"audio validation rejects an empty sample bank")
	var registry = preload("res://tests/content_validation_checks.gd").new().registry_copy()
	var copy: AbilityData = registry.abilities["ability.spark"].duplicate()
	copy.audio_profile = invalid
	registry.abilities["ability.spark"] = copy
	check.call(str(registry.validate()).contains("impact_samples"),"content validation includes nested audio diagnostics")
	registry.free()
	Audio.enabled = enabled
	Audio.rng.state = rng_state
	Audio.last_sample = samples
