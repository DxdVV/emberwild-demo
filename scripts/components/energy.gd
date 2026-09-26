class_name EnergyComponent extends RefCounted
var maximum: float = 100
var current: float = 100
var regeneration: float = 13

func spend(cost: float) -> bool:
	if cost > current: return false
	current -= maxf(0,cost)
	return true

func tick(delta: float) -> void:
	current = minf(maximum,current + regeneration * delta)
