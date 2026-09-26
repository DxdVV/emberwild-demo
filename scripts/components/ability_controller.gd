class_name AbilityController extends RefCounted

enum Phase {IDLE, WINDUP, RECOVERY}
signal phase_changed(phase: Phase)
var actor
var phase: Phase = Phase.IDLE
var remaining: float = 0
var current: AbilityData
var target_ref: WeakRef
var cooldowns := CooldownComponent.new()

func cast(id: String, target) -> bool:
	if phase != Phase.IDLE or actor.health.current <= 0 or not Database.abilities.has(id): return false
	var definition: AbilityData = Database.abilities[id]
	if not TargetingSystem.valid(actor,target) or actor.global_position.distance_to(target.global_position) > definition.reach: return false
	if not cooldowns.available(definition) or not actor.energy.spend(definition.cost): return false
	current = definition
	target_ref = weakref(target)
	cooldowns.use(definition,actor.stats.value("cooldown_reduction"))
	phase = Phase.WINDUP
	remaining = definition.windup
	actor.presentation.cast(definition.color)
	actor.triggers.fire("ability_cast",{"target":target})
	phase_changed.emit(phase)
	return true

func interrupt() -> void:
	phase = Phase.IDLE
	current = null
	target_ref = null
	remaining = 0

func tick(delta: float) -> void:
	if phase == Phase.IDLE: return
	remaining -= delta
	if remaining > 0: return
	if phase == Phase.WINDUP:
		var target = target_ref.get_ref() if target_ref != null else null
		if TargetingSystem.valid(actor,target): actor.world.launch(actor,target,current)
		phase = Phase.RECOVERY
		remaining = current.recovery
	else: phase = Phase.IDLE
	phase_changed.emit(phase)
