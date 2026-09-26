extends RefCounted

func run(session, check: Callable) -> void:
	var labels := WorldLabels.new()
	labels.size = Vector2(960,540)
	var previous: Array[Rect2] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 731
	var equal := true
	for index in 240:
		var at := Vector2(rng.randi_range(-20,980),rng.randi_range(65,490))
		var text: String = ["Угольный фокус","R · Призма эха","Корень первозданных","Ember focus"][index%4]
		var expected := reference_place(text,at,previous,labels.size)
		var actual := labels.place(text,at)
		equal = equal and expected==actual
	check.call(equal and labels.label_rects==previous,"strip-indexed loot placement matches exhaustive overlap checks across dense, edge and offscreen cases")
	check.call(labels.widths.size()==4,"repeated loot names reuse measured text widths")
	for viewport_size in [Vector2(320,240),Vector2(640,360),Vector2(960,540),Vector2(1920,1080)]:
		var edge_labels := WorldLabels.new()
		edge_labels.size = viewport_size
		var edge_reference: Array[Rect2] = []
		var edges_equal := true
		for index in 320:
			var at := Vector2(rng.randf_range(-10,viewport_size.x+10),rng.randf_range(-30,viewport_size.y+30))
			if index%3==0: at = at.floor()+Vector2(.5,.5)
			var text: String = ["R · Призма эха","Ember focus","Очень длинное название предмета ".repeat(8)][index%3]
			var expected := reference_place(text,at,edge_reference,viewport_size)
			edges_equal = edges_equal and edge_labels.place(text,at)==expected
		check.call(edges_equal and edge_labels.label_rects==edge_reference,"loot placement preserves fractional edges and oversized names at "+str(viewport_size))
		edge_labels.free()
	TranslationServer.set_locale("en")
	labels._notification(Control.NOTIFICATION_TRANSLATION_CHANGED)
	check.call(labels.widths.is_empty() and labels.dirty,"translation changes invalidate measured label widths")
	TranslationServer.set_locale("ru")
	labels.free()
	var world: GameWorld = session.world
	var before := world.drops.duplicate(true)
	var filter_before := Settings.loot_filter.to_dict()
	var reveal_before := world.reveal_loot
	world.drops.clear()
	for index in 8: world.drops.append({"at":world.trainer.position+Vector2(10+index*10,0),"item":{"base":"item.ember","rarity":index%4,"id":"layout-check-"+str(index)}})
	Settings.loot_filter.restore({"minimum_rarity":2})
	world.reveal_loot = false
	var hud_labels: WorldLabels = session.hud.world_labels
	hud_labels.refresh_drop_order(world)
	check.call(hud_labels.ordered_drops==[3,7,2,6] and world.visible_drop_indices()==[2,3,6,7],"cached ordering retains rarity priority and all filtered pickup indices")
	world.reveal_loot = true
	hud_labels.refresh_drop_order(world)
	check.call(hud_labels.ordered_drops==[3,7,2,6,1,5,0,4] and world.pickup_candidate()==0,"temporary reveal includes every rarity while pickup still chooses the nearest item")
	hud_labels.order_dirty = false
	world.refresh_labels()
	hud_labels._process(0)
	check.call(hud_labels.order_dirty,"loot changes invalidate sorted display order")
	hud_labels.order_dirty = false
	Settings.changed.emit()
	check.call(hud_labels.order_dirty,"filter and control settings invalidate sorted display order")
	hud_labels._process(0)
	hud_labels.refresh_drop_order(world)
	# Headless ownership checks must perform the same pre-draw cache refresh
	# as the rendered path before constructing a simulated hovered item.
	hud_labels.begin_layout()
	hud_labels.hovered_index = 2
	hud_labels.hovered_item = world.drops[2].item
	var item_snapshot := hud_labels.hovered_item.duplicate(true)
	var rng_before: int = world.item_generator.rng.state
	check.call(hud_labels.hover_description()==TooltipPresenter.item_summary(item_snapshot),"ground description shares inventory mechanics for the exact item instance")
	check.call(item_snapshot==hud_labels.hovered_item and rng_before==world.item_generator.rng.state,"reading ground properties never mutates the item or loot RNG")
	var removed: Dictionary = world.drops.pop_front()
	check.call(hud_labels.hover_description().is_empty(),"removing an earlier drop cannot retarget an old hover index to a different item")
	world.drops.push_front(removed)
	world.refresh_labels()
	check.call(hud_labels.hover_description().is_empty(),"loot revision invalidates an open description before the next UI frame")
	world.reveal_loot = false
	Settings.loot_filter.restore({"minimum_rarity":3})
	hud_labels._process(0)
	hud_labels.refresh_drop_order(world)
	check.call(not hud_labels.valid_drop(2,world.drops[2].item),"filtered ground items cannot expose properties through old hit rectangles")
	world.reveal_loot = true
	hud_labels._process(0)
	hud_labels.refresh_drop_order(world)
	check.call(hud_labels.valid_drop(2,world.drops[2].item),"temporary reveal restores ground inspection eligibility")
	hud_labels.clear_hover()
	check.call(not hud_labels.hover_control.visible and hud_labels.hover_description().is_empty(),"cleared hover releases its item and hit target")
	world.drops = before
	world.reveal_loot = reveal_before
	Settings.loot_filter.restore(filter_before)
	world.refresh_labels()

func reference_place(text: String, at: Vector2, placed: Array[Rect2], size: Vector2) -> Rect2:
	if at.x<0 or at.x>size.x: return Rect2()
	var width := ThemeDB.fallback_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+12
	var bounds := Rect2(10,90,size.x-20,size.y-180)
	for offset in [0,-24,-48,-72,24,48,72,-96]:
		var rect := Rect2(Vector2(at.x-width*.5,at.y-20+offset).round(),Vector2(width,22))
		rect.position.x = clampf(rect.position.x,bounds.position.x,bounds.end.x-width)
		if not bounds.encloses(rect): continue
		var collision := false
		for other in placed:
			if other.grow(2).intersects(rect): collision = true; break
		if collision: continue
		placed.append(rect)
		return rect
	return Rect2()
