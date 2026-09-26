extends Node

# Frozen previous production strip algorithm, not an intentionally slow scan.
class Strips extends RefCounted:
	var bands := {}
	var rects: Array[Rect2] = []
	var widths := {}
	var size := Vector2(960,540)
	func place(text: String, at: Vector2) -> Rect2:
		if at.x<0 or at.x>size.x: return Rect2()
		if not widths.has(text): widths[text] = ThemeDB.fallback_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+12
		var width: float = widths[text]
		var bounds := Rect2(10,90,maxf(1,size.x-20),maxf(1,size.y-180))
		for offset in [0,-24,-48,-72,24,48,72,-96]:
			var rect := Rect2(Vector2(at.x-width*.5,at.y-20+offset).round(),Vector2(width,22))
			rect.position.x = clampf(rect.position.x,bounds.position.x,bounds.end.x-width)
			if not bounds.encloses(rect) or overlaps(rect): continue
			rects.append(rect)
			var padded := rect.grow(2)
			for band in range(floori(padded.position.y/32),floori(padded.end.y/32)+1):
				if not bands.has(band): bands[band] = []
				bands[band].append(padded)
			return rect
		return Rect2()
	func overlaps(rect: Rect2) -> bool:
		for band in range(floori(rect.position.y/32),floori(rect.end.y/32)+1):
			for occupied: Rect2 in bands.get(band,[]):
				if occupied.intersects(rect): return true
		return false

func _ready() -> void: run.call_deferred()

func run() -> void:
	var optimized := WorldLabels.new()
	optimized.size = Vector2(960,540)
	var baseline := Strips.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 39847
	var cases: Array = []
	for dense in [false,true]:
		var points: Array[Vector2] = []
		for index in 240:
			points.append(Vector2(rng.randf_range(350,650),rng.randf_range(190,340)) if dense else Vector2(rng.randf_range(-20,980),rng.randf_range(65,490)))
		cases.append({"name":"dense" if dense else "spread","points":points})
	var samples: Array = []
	var equal := true
	for scenario in cases:
		for repetition in 5:
			var sample := {"case":scenario.name}
			var outputs := {}
			for current in [true,false] if repetition%2==0 else [false,true]:
				var rectangles: Array[Rect2] = []
				var start := Time.get_ticks_usec()
				for frame in 100:
					optimized.label_rects.clear()
					optimized.label_bands.clear()
					baseline.rects.clear()
					baseline.bands.clear()
					rectangles.clear()
					for index in scenario.points.size():
						var text: String = ["Угольный фокус","R · Призма эха","Корень первозданных","Ember focus"][index%4]
						var at: Vector2 = scenario.points[index]
						rectangles.append(optimized.place(text,at) if current else baseline.place(text,at))
				sample["current_us" if current else "baseline_us"] = Time.get_ticks_usec()-start
				outputs[current] = rectangles.duplicate()
			equal = equal and outputs[true]==outputs[false]
			samples.append(sample)
	optimized.free()
	var result := {"equivalent":equal,"frames_per_sample":100,"drops":240,"samples":samples}
	FileAccess.open("res://build/loot-layout-benchmark.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("LOOT LAYOUT BENCHMARK ",JSON.stringify(result))
	get_tree().quit(0 if equal else 1)
