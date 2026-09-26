extends Node

func _ready() -> void:
	var navigation := WorldNavigation.new()
	# Same occupied envelope as the old probe, now passing actual unexpanded geometry.
	navigation.configure(Vector2(600,600),[Rect2(266,196,68,168)])
	var at := Vector2(242,300)
	var target := Vector2(430,300)
	for step in 900: at += navigation.direction(at,target)*minf(2,at.distance_to(target))
	print("NAVIGATION CELL EDGE start=(242,300) end=",at," remaining=",at.distance_to(target))
	get_tree().quit()
