class_name AbilityProjectile extends Area2D

var world
var source_ref: WeakRef
var target_ref: WeakRef
var ability: AbilityData
var context: Dictionary = {}
var life: float = 2.5
var trail: Array[Vector2] = []
var impacted: bool = false

func _ready() -> void:
	collision_layer = 8
	collision_mask = 4
	monitorable = false
	z_index = 10
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9
	shape.shape = circle
	add_child(shape)
	area_entered.connect(on_area)

func _physics_process(delta: float) -> void:
	if impacted: return
	life -= delta
	var target = target_ref.get_ref()
	var source = source_ref.get_ref()
	if life <= 0 or not TargetingSystem.valid(source,target):
		queue_free()
		return
	trail.push_front(global_position)
	if trail.size()>7: trail.pop_back()
	global_position = global_position.move_toward(target.global_position,ability.projectile_speed*delta)
	if global_position.distance_squared_to(target.global_position)<64: impact(target)
	queue_redraw()

func on_area(area: Area2D) -> void:
	var actor = area.get_meta("actor",null)
	if TargetingSystem.valid(source_ref.get_ref(),actor): impact(actor)

func impact(target) -> void:
	if impacted: return
	impacted = true
	world.resolve_hit(source_ref.get_ref(),target,ability,context)
	queue_free()

func _draw() -> void:
	for i in trail.size(): draw_circle(to_local(trail[i])+Vector2(0,-20),maxf(1,4-i*.5),Color(ability.color,.6-i*.07))
	draw_circle(Vector2(0,-20),5,ability.color)
	draw_circle(Vector2(0,-21),2,Color("fff9dc"))
