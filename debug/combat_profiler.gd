class_name CombatProfiler extends RefCounted

static var enabled: bool = false
static var samples: Dictionary = {}

static func start() -> int:
	return Time.get_ticks_usec() if enabled else 0

static func finish(section: String, started: int) -> void:
	if started==0: return
	var elapsed := Time.get_ticks_usec()-started
	if not samples.has(section): samples[section] = {"calls":0,"total_us":0,"max_us":0}
	var sample: Dictionary = samples[section]
	sample.calls += 1
	sample.total_us += elapsed
	sample.max_us = maxi(sample.max_us,elapsed)

static func reset() -> void: samples.clear()
