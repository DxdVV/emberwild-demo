class_name GroundHazard extends Node2D

var world
var source_ref: WeakRef
var radius: float = 100
var duration: float = 1.2
var elapsed: float = 0
var activated: bool = false
var created_physics_frame: int = -1

func _ready() -> void:
	world.hazards.append(self)
	z_index = -1
	var canvas := CanvasItemMaterial.new()
	canvas.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = canvas
	created_physics_frame = Engine.get_physics_frames()

func _exit_tree() -> void:
	if is_instance_valid(world): world.hazards.erase(self)

func _physics_process(delta: float) -> void:
	# Nodes added during a physics tick can receive that same tick's callback.
	# Begin elapsed time on the next tick, just like the source's cast timer.
	advance(0.0 if Engine.get_physics_frames()==created_physics_frame else delta)

func advance(delta: float) -> void:
	var source = source_ref.get_ref()
	if not activated and (not is_instance_valid(source) or source.health.current<=0 or source.is_queued_for_deletion()):
		queue_free()
		return
	elapsed += delta
	if not activated and elapsed >= duration:
		activated = true
		Audio.play_ability(Database.abilities["ability.slam"],"impact",global_position)
		if is_instance_valid(source):
			for target in TargetingSystem.area(source,world.actors,global_position,radius): world.damage.apply(source,target,Database.abilities["ability.slam"])
		world.effects.burst(global_position,Color("ffb569"),28)
		world.camera.impulse(3)
	if elapsed >= duration+.3: queue_free()
	queue_redraw()

func _draw() -> void:
	var ratio := minf(1,elapsed/duration)
	draw_circle(Vector2.ZERO,radius,Color(1,.23,.13,.08 if not activated else .35))
	draw_arc(Vector2.ZERO,radius,0,TAU,64,Color("21171c"),6)
	draw_arc(Vector2.ZERO,radius,0,TAU,64,Color("ff8a65"),2)
	draw_arc(Vector2.ZERO,radius*ratio,0,TAU,48,Color("21171c"),4)
	draw_arc(Vector2.ZERO,radius*ratio,0,TAU,48,Color(1,.63,.35,.5),2)
	for i in 8:
		var direction := Vector2.from_angle(i*TAU/8)
		draw_line(direction*(radius-8),direction*(radius+3),Color("21171c"),6)
		draw_line(direction*(radius-8),direction*(radius+3),Color("ffc686"),2)
