class_name AbilityAudioData extends Resource

@export var id: StringName
@export var cast_samples: Array[AudioStream] = []
@export var impact_samples: Array[AudioStream] = []
@export_range(-40,0) var cast_gain_db: float = -4
@export_range(-40,0) var impact_gain_db: float = -4

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var at := "%s [%s]"%[resource_path,id]
	if str(id).is_empty(): errors.append(at+" / id: empty audio identity")
	for field in ["cast_samples","impact_samples"]:
		var samples: Array = get(field)
		if samples.is_empty() or samples.size()>16: errors.append(at+" / "+field+": expected 1–16 samples")
		for index in samples.size():
			if samples[index]==null or samples[index].get_length()<=0: errors.append(at+" / "+field+"[%d]: missing/empty stream"%index)
	for field in ["cast_gain_db","impact_gain_db"]:
		if not CombatSaveSchema.number(get(field),-40,0): errors.append(at+" / "+field+": expected finite gain from -40 to 0 dB")
	return errors
