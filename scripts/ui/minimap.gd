class_name MinimapView extends Control
var world
var background: StyleBox
var remaining: float = 0

func _ready() -> void: background = UIStyle.box(Color(.03,.09,.08,.85),Color("566550"))

func _process(delta: float) -> void:
	remaining -= delta
	if remaining<=0:
		remaining = .1
		queue_redraw()

func _draw() -> void:
	if not is_instance_valid(world): return
	draw_style_box(background,Rect2(Vector2.ZERO,size))
	var scale_factor: Vector2 = (size-Vector2(16,16))/world.area.size
	for segment in world.area.layout.segments():
		draw_line(Vector2(8,8)+segment.from*scale_factor,Vector2(8,8)+segment.to*scale_factor,Color("7a7860"),2)
	for interaction in world.area.layout.interactions:
		var marker := Vector2(8,8)+AreaLayout.point(interaction.at)*scale_factor
		draw_rect(Rect2(marker-Vector2(2,2),Vector2(4,4)),UIStyle.GOLD)
	for actor in world.actors:
		if not is_instance_valid(actor) or actor.health.current<=0: continue
		var color := Color("e0be7a") if actor==world.trainer else Color("77bda1")
		if actor.faction>=Factions.Team.WILD: color = Color("e07862")
		draw_circle(Vector2(8,8)+actor.position*scale_factor,3 if actor==world.trainer else 1.5,color)
	var at: Vector2 = world.trainer.position*scale_factor+Vector2(8,8)
	draw_arc(at,6,0,TAU,16,UIStyle.PAPER,1)
