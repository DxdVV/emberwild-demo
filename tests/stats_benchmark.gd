extends Node

# A focused query-cost benchmark, not evidence of interactive frame pacing.
const QUERIES := 120000
const STATS := ["attack","defense","health","speed","energy_regeneration","critical_chance"]
var model := StatsComponent.new()
var sources: Array = []

func _ready() -> void:
	model.base = {"attack":30.0,"defense":10.0,"health":200.0,"speed":90.0,"energy_regeneration":14.0,"critical_chance":.05}
	model.level = 5
	for index in 12:
		var source := [{"stat":STATS[index%6],"op":"flat","value":float(index+1)},{"stat":STATS[(index+2)%6],"op":"add","value":.1},{"stat":STATS[(index+4)%6],"op":"multiply","value":1.05}]
		sources.append(source)
		model.set_source(str(index),source)
	var samples: Array = []
	var valid := true
	for repetition in 5:
		# Alternate order to avoid always benchmarking one path after the same warmup.
		var result := {}
		for compiled in ([true,false] if repetition%2==0 else [false,true]):
			var total := 0.0
			var start := Time.get_ticks_usec()
			for query in QUERIES:
				var stat: String = STATS[query%6]
				total += model.value(stat) if compiled else original_query(stat)
			result["compiled_us" if compiled else "scan_us"] = Time.get_ticks_usec()-start
			result["compiled_checksum" if compiled else "scan_checksum"] = total
		valid = valid and is_equal_approx(result.compiled_checksum,result.scan_checksum)
		samples.append(result)
	var report := {"queries_per_sample":QUERIES,"sources":sources.size(),"equivalent":valid,"samples":samples}
	FileAccess.open("res://build/stats-benchmark.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("STATS BENCHMARK ",JSON.stringify(report))
	get_tree().quit(0 if valid else 1)

func original_query(stat: String) -> float:
	var initial: float = model.base.get(stat,0.0)
	if stat in ["health","attack","defense"]: initial *= 1+(model.level-1)*model.scaling
	var flat := 0.0
	var additive := 0.0
	var multiplier := 1.0
	var override_value = null
	for source in sources:
		for modifier in source:
			if modifier.get("stat")!=stat: continue
			var amount: float = modifier.get("value",0.0)
			match modifier.get("op","flat"):
				"flat": flat += amount
				"add": additive += amount
				"multiply": multiplier *= amount
				"override": override_value = amount
	var value: float = float(override_value) if override_value!=null else (initial+flat)*(1+additive)*multiplier
	return clampf(value,0,1) if stat=="critical_chance" else maxf(0,value)
