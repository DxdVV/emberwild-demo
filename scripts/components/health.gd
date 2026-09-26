class_name HealthComponent extends RefCounted

signal changed(current: float, maximum: float)
signal died
var maximum: float = 100
var current: float = 100
var invulnerable: float = 0
var shield: float = 0
var immortal: bool = false

func reset(amount: float, ratio: float = 1.0) -> void:
	maximum = maxf(1,amount)
	current = clampf(maximum * ratio,0,maximum)
	changed.emit(current,maximum)

func damage(amount: float) -> Dictionary:
	if current <= 0 or invulnerable > 0 or immortal: return {"damage":0.0,"absorbed":0.0,"blocked":true,"killed":false}
	var absorbed := minf(shield,maxf(amount,0))
	shield -= absorbed
	var dealt := minf(current,maxf(0,amount-absorbed))
	current -= dealt
	changed.emit(current,maximum)
	if current <= 0: died.emit()
	return {"damage":dealt,"absorbed":absorbed,"blocked":false,"killed":current <= 0}

func heal(amount: float) -> void:
	if current <= 0: return
	current = minf(maximum,current + maxf(0,amount))
	changed.emit(current,maximum)

func tick(delta: float) -> void:
	invulnerable = maxf(0,invulnerable-delta)
