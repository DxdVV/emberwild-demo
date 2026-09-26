extends RefCounted

class Probe extends WorldLabels:
	func _draw() -> void: pass

func settle(tree: SceneTree) -> void:
	for frame in 3: await tree.process_frame

func run(session, check: Callable) -> void:
	var parent := Control.new()
	parent.size = Vector2(960,540)
	parent.position = Vector2(13,11)
	parent.scale = Vector2(.75,1.25)
	parent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	session.add_child(parent)
	var labels := Probe.new()
	labels.session = session
	labels.set_process(false)
	parent.add_child(labels)
	var blocker := Control.new()
	blocker.position = Vector2(350,200)
	blocker.size = Vector2(300,80)
	blocker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(blocker)
	labels.reserve_controls([blocker])
	await settle(session.get_tree())
	labels.begin_layout()
	var expected := Rect2(blocker.position,blocker.size).grow(4)
	check.call(labels.reserved_rects.size()==1 and labels.reserved_rects[0].is_equal_approx(expected),"HUD exclusion converts translated/scaled parent geometry into label coordinates")
	var moved := labels.place("R · Призма эха",Vector2(460,250))
	check.call(moved.has_area() and not moved.intersects(expected),"selected loot finds another candidate outside a tall HUD exclusion")
	var clear := true
	for y in range(180,305,12):
		var placed := labels.place("Ember focus",Vector2(480,y))
		clear = clear and (not placed.has_area() or not placed.intersects(expected))
	check.call(clear,"HUD exclusion is indexed across every touched strip")
	labels.drop_regions.append({"index":0})
	labels.hover_control.show()
	blocker.hide()
	check.call(labels.reserved_dirty and labels.drop_regions.is_empty() and not labels.hover_control.visible,"HUD visibility change immediately invalidates stale ground hit targets")
	labels.begin_layout()
	var restored := labels.place("R · Призма эха",Vector2(460,250))
	check.call(labels.reserved_rects.is_empty() and restored.has_area() and restored.position.y==230,"hiding HUD returns the original loot placement candidate")
	blocker.show()
	blocker.position = Vector2(200,110)
	blocker.size = Vector2(280,170)
	await settle(session.get_tree())
	labels.begin_layout()
	check.call(labels.reserved_rects[0].is_equal_approx(Rect2(blocker.position,blocker.size).grow(4)),"moving or resizing HUD refreshes its exclusion")
	var empty_label := Label.new()
	empty_label.position = Vector2(450,200)
	empty_label.size = Vector2(200,50)
	parent.add_child(empty_label)
	labels.reserve_controls([empty_label])
	labels.begin_layout()
	check.call(labels.reserved_rects.is_empty(),"empty HUD labels do not consume loot space")
	empty_label.text = "A long visible HUD message which resizes the label"
	await settle(session.get_tree())
	labels.begin_layout()
	check.call(labels.reserved_rects.size()==1,"visible resized HUD text acquires an exclusion")
	empty_label.text = ""
	await settle(session.get_tree())
	labels.begin_layout()
	check.call(labels.reserved_rects.is_empty(),"clearing text releases HUD space even when its Control keeps its size")
	empty_label.queue_free()
	await settle(session.get_tree())
	labels.begin_layout()
	check.call(labels.reserved_rects.is_empty(),"removed HUD controls release exclusions through weak references")
	parent.queue_free()
	await settle(session.get_tree())
