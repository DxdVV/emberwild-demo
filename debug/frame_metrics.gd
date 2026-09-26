class_name FrameMetrics extends RefCounted

var intervals: Array[float] = []
var render_cpu: Array[float] = []
var render_gpu: Array[float] = []
var timeline: Array[Dictionary] = []
var started_us: int = 0
var previous_us: int = 0
var first_drawn: int = 0
var previous_drawn: int = 0
var first_physics: int = 0
var previous_physics: int = 0
var unfocused: int = 0
var missing_draws: int = 0

func begin(now: int, drawn: int, physics: int) -> void:
	intervals.clear()
	render_cpu.clear()
	render_gpu.clear()
	timeline.clear()
	started_us = now
	previous_us = now
	first_drawn = drawn
	previous_drawn = drawn
	first_physics = physics
	previous_physics = physics
	unfocused = 0
	missing_draws = 0

func sample(now: int, drawn: int, physics: int, focused: bool, cpu_ms: float, gpu_ms: float) -> void:
	var duration := (now-previous_us)/1000.0
	intervals.append(duration)
	render_cpu.append(cpu_ms)
	render_gpu.append(gpu_ms)
	if not focused: unfocused += 1
	if drawn<=previous_drawn: missing_draws += 1
	timeline.append({"time_ms":(now-started_us)/1000.0,"frame_ms":duration,"drawn_delta":drawn-previous_drawn,"physics_delta":physics-previous_physics,"focused":focused,"render_cpu_ms":cpu_ms,"render_gpu_ms":gpu_ms})
	previous_us = now
	previous_drawn = drawn
	previous_physics = physics

static func distribution(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {"samples":0}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value in values: total += value
	return {"samples":values.size(),"mean":total/values.size(),"p50":sorted[maxi(0,ceili(values.size()*.5)-1)],"p95":sorted[maxi(0,ceili(values.size()*.95)-1)],"p99":sorted[maxi(0,ceili(values.size()*.99)-1)],"max":sorted[-1]}

func report() -> Dictionary:
	var elapsed := (previous_us-started_us)/1000000.0
	return {"wall_seconds":elapsed,"drawn_frames":previous_drawn-first_drawn,"physics_frames":previous_physics-first_physics,"delivered_fps":(previous_drawn-first_drawn)/elapsed if elapsed>0 else 0,"frame_ms":distribution(intervals),"render_cpu_ms":distribution(render_cpu),"render_gpu_ms":distribution(render_gpu),"render_timing_available":render_gpu.any(func(value): return value>0),"unfocused_samples":unfocused,"samples_without_draw":missing_draws,"frames_over_25ms":intervals.filter(func(value): return value>25).size(),"frames_over_50ms":intervals.filter(func(value): return value>50).size(),"pacing_sample_valid":not intervals.is_empty() and unfocused==0 and missing_draws==0,"timeline":timeline.duplicate(true)}
