class_name CameraController extends Camera2D

var target: Node2D
var trauma: float = 0
var follow_position: Vector2
var cinematic: bool = false
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 725
	position_smoothing_enabled = false
	zoom = Vector2(.5,.5)

func set_bounds(size: Vector2) -> void:
	limit_left = 0
	limit_top = 0
	limit_right = int(size.x)
	limit_bottom = int(size.y)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target) or cinematic: return
	var look: Vector2 = (get_global_mouse_position()-target.global_position).limit_length(50)*.35
	follow_position = follow_position.lerp(target.global_position+look,1-exp(-delta*6))
	global_position = (follow_position*.5).round()*2
	trauma = maxf(0,trauma-delta*15)
	offset = Vector2(rng.randf_range(-trauma,trauma),rng.randf_range(-trauma,trauma)).round() if Settings.shake else Vector2.ZERO

func impulse(amount: float) -> void: trauma = minf(10,trauma+amount)

func snap(at: Vector2) -> void:
	follow_position = at
	global_position = at.round()
	reset_smoothing()
