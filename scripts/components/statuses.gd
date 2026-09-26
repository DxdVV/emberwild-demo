class_name StatusComponent extends RefCounted

signal changed
var state_ref: WeakRef
var entries: Dictionary = {}

static func duration_for(definition: StatusData, stats: StatsComponent = null, bonus: float = 0) -> float:
	return clampf(definition.duration+bonus+(stats.value("status_duration") if stats!=null else 0.0),0,StatusData.MAX_DURATION)

func apply(id: String, source, bonus: float = 0) -> void:
	var state: CombatState = state_ref.get_ref() if state_ref != null else null
	if state==null or not Database.statuses.has(id) or state.health.current<=0: return
	var definition: StatusData = Database.statuses[id]
	var duration := duration_for(definition,source.stats if is_instance_valid(source) else null,bonus)
	if duration<=0: return
	var snapshot: Dictionary = {}
	if is_instance_valid(source):
		snapshot = {"id":source.identity,"faction":source.faction,"attack":source.stats.value("attack"),"critical_chance":source.critical_chance}
	if entries.has(id):
		entries[id].stacks = mini(definition.max_stacks,entries[id].stacks+1)
		if definition.refresh: entries[id].remaining = duration
		entries[id].source = snapshot
	else:
		entries[id] = {"definition":definition,"remaining":duration,"tick":definition.tick_interval,"stacks":1,"source":snapshot}
	state.stats.set_source("status:"+id,definition.modifiers)
	changed.emit()

func remove(id: String) -> void:
	entries.erase(id)
	var state: CombatState = state_ref.get_ref() if state_ref != null else null
	if state != null: state.stats.remove_source("status:"+id)
	changed.emit()

func clear() -> void:
	for id in entries.keys(): remove(id)

func tick(delta: float) -> void:
	var state: CombatState = state_ref.get_ref() if state_ref != null else null
	if state==null: return
	for id in entries.keys():
		if not entries.has(id): continue
		var entry: Dictionary = entries[id]
		# Count only elapsed time before expiry, including the boundary tick.
		entry.tick -= minf(delta,entry.remaining)
		entry.remaining = maxf(0,entry.remaining-delta)
		var interval := maxf(.001,entry.definition.tick_interval)
		while entry.tick<=.000001:
			entry.tick += interval
			if entry.definition.tick_power>0 and state.health.current>0 and state.damage_system != null:
				state.damage_system.apply_periodic(entry.source,state,id,entry.definition,entry.stacks)
		if entry.remaining <= 0: remove(id)

func to_array() -> Array:
	var result: Array = []
	for id in entries:
		var entry: Dictionary = entries[id]
		result.append({"id":id,"remaining":entry.remaining,"tick":entry.tick,"stacks":entry.stacks,"source":entry.source.duplicate()})
	return result

func restore(data: Array) -> void:
	clear()
	var state: CombatState = state_ref.get_ref() if state_ref != null else null
	if state==null: return
	for entry in data:
		var id: String = entry.get("id","")
		if not Database.statuses.has(id) or float(entry.get("remaining",0))<=0: continue
		var definition: StatusData = Database.statuses[id]
		entries[id] = {"definition":definition,"remaining":clampf(float(entry.remaining),0,StatusData.MAX_DURATION),"tick":clampf(float(entry.get("tick",definition.tick_interval)),0,maxf(.001,definition.tick_interval)),"stacks":clampi(int(entry.get("stacks",1)),1,definition.max_stacks),"source":entry.get("source",{}).duplicate()}
		state.stats.set_source("status:"+id,definition.modifiers)
	changed.emit()
