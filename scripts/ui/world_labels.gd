class_name WorldLabels extends Control

var session
var previous_world: int = 0
var previous_transform := Transform2D()
var previous_position := Vector2.INF
var previous_revision: int = -1
var previous_reveal: bool = false
var dirty: bool = true
var label_rects: Array[Rect2] = []
var label_bands: Dictionary = {}
const LABEL_OFFSETS := [0,-24,-48,-72,24,48,72,-96]
var widths: Dictionary = {}
var ordered_drops: Array[int] = []
var cached_count: int = -1
var order_dirty: bool = true
var drop_regions: Array[Dictionary] = []
var hover_control: Control
var hovered_index: int = -1
var hovered_item: Dictionary = {}
var reserved_controls: Array[WeakRef] = []
var reserved_rects: Array[Rect2] = []
var reserved_dirty: bool = true
const COLORS := [Color("ccc9b0"),Color("8cb9e9"),Color("eac577"),Color("e5a966")]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Settings.changed.connect(func(): dirty = true; order_dirty = true)
	# One reusable hit target for the label under the pointer, never one node per drop.
	hover_control = Control.new()
	hover_control.name = "GroundItemHover"
	ContextTooltip.bind(hover_control,hover_description,false)
	add_child(hover_control)
	hover_control.hide()

func _notification(what: int) -> void:
	if what==NOTIFICATION_TRANSLATION_CHANGED:
		widths.clear()
		dirty = true
		reserved_dirty = true

func reserve_controls(controls: Array) -> void:
	reserved_controls.clear()
	for control: Control in controls:
		reserved_controls.append(weakref(control))
		for event in [control.item_rect_changed,control.minimum_size_changed,control.visibility_changed,control.tree_exiting]:
			if not event.is_connected(invalidate_reserved): event.connect(invalidate_reserved)
	invalidate_reserved()

func invalidate_reserved() -> void:
	reserved_dirty = true
	dirty = true
	# A newly visible HUD control must not inherit a stale ground-item hit region.
	drop_regions.clear()
	clear_hover()
	queue_redraw()

func refresh_reserved() -> void:
	if not reserved_dirty: return
	reserved_rects.clear()
	var inverse := get_global_transform().affine_inverse()
	for reference in reserved_controls:
		var control = reference.get_ref()
		if not is_instance_valid(control) or not control.is_visible_in_tree(): continue
		if control is Label and control.text.is_empty(): continue
		var rect: Rect2 = inverse*control.get_global_rect()
		if rect.has_area(): reserved_rects.append(rect.grow(4))
	reserved_dirty = false

func begin_layout() -> void:
	refresh_reserved()
	label_rects.clear()
	label_bands.clear()
	drop_regions.clear()
	# HUD regions can span more than the two strips used by a single 22px label.
	for rect in reserved_rects:
		for band in range(floori(rect.position.y/32),floori(rect.end.y/32)+1):
			if not label_bands.has(band): label_bands[band] = []
			label_bands[band].append(rect)

func _process(_delta: float) -> void:
	if not is_instance_valid(session.world): clear_hover(); return
	var world: GameWorld = session.world
	visible = world.trainer.health.current>0
	var transform := world.get_viewport().get_canvas_transform()
	if previous_world!=world.get_instance_id() or previous_revision!=world.labels_revision or previous_reveal!=world.reveal_loot or cached_count!=world.drops.size(): order_dirty = true
	if dirty or order_dirty or previous_world!=world.get_instance_id() or previous_transform!=transform or previous_position!=world.trainer.position or previous_revision!=world.labels_revision or previous_reveal!=world.reveal_loot:
		# Content changes invalidate indices immediately; camera motion keeps the last
		# displayed rectangles until the next draw replaces them.
		if dirty or order_dirty: drop_regions.clear()
		dirty = false
		previous_world = world.get_instance_id()
		previous_transform = transform
		previous_position = world.trainer.position
		previous_revision = world.labels_revision
		previous_reveal = world.reveal_loot
		queue_redraw()
	refresh_hover()

func clear_hover() -> void:
	hovered_index = -1
	hovered_item = {}
	if is_instance_valid(hover_control): hover_control.hide()

func refresh_hover() -> void:
	if not visible or not is_instance_valid(session.world): clear_hover(); return
	var at := get_local_mouse_position()
	for entry in drop_regions:
		if entry.rect.has_point(at) and valid_drop(entry.index,entry.item):
			hovered_index = entry.index
			hovered_item = entry.item
			hover_control.set_meta(ContextTooltip.IDENTITY,str(previous_world)+":"+str(hovered_item.id))
			hover_control.position = entry.rect.position
			hover_control.size = entry.rect.size
			hover_control.show()
			return
	clear_hover()

func valid_drop(index: int, item: Dictionary) -> bool:
	if not is_instance_valid(session.world): return false
	var world: GameWorld = session.world
	if previous_world!=world.get_instance_id() or previous_revision!=world.labels_revision or previous_reveal!=world.reveal_loot or dirty or order_dirty or reserved_dirty: return false
	if index<0 or index>=world.drops.size() or not is_same(world.drops[index].item,item): return false
	return world.reveal_loot or Settings.loot_filter.accepts(item)

func hover_description() -> String:
	if not valid_drop(hovered_index,hovered_item): return ""
	return TooltipPresenter.item_summary(hovered_item)

func hover_target(gui_owner: Control) -> Control:
	# Never override a modal, effect badge or other real UI control above the world.
	if gui_owner!=null and gui_owner!=session.world_container and gui_owner!=hover_control: return null
	return hover_control if hover_control.visible and valid_drop(hovered_index,hovered_item) else null

func project(at: Vector2) -> Vector2:
	return (session.world.get_viewport().get_canvas_transform()*at)*(session.world_container.size/Vector2(session.world_viewport.size))

func place(text: String, at: Vector2) -> Rect2:
	if at.x<0 or at.x>size.x: return Rect2()
	if not widths.has(text):
		if widths.size()>=128: widths.clear()
		widths[text] = ThemeDB.fallback_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+12
	var width: float = widths[text]
	var bounds := Rect2(10,90,maxf(1,size.x-20),maxf(1,size.y-180))
	if width>bounds.size.x: return Rect2()
	var left := clampf(roundf(at.x-width*.5),bounds.position.x,bounds.end.x-width)
	var top := roundf(at.y-20)
	# Horizontal placement and rounding are invariant across the eight candidates.
	for offset in LABEL_OFFSETS:
		var y: float = top+offset
		if y<bounds.position.y or y+22>bounds.end.y: continue
		var rect := Rect2(left,y,width,22)
		if overlaps(rect): continue
		label_rects.append(rect)
		var padded := rect.grow(2)
		var first := floori(padded.position.y/32)
		var last := floori(padded.end.y/32)
		if not label_bands.has(first): label_bands[first] = []
		label_bands[first].append(padded)
		if last!=first:
			if not label_bands.has(last): label_bands[last] = []
			label_bands[last].append(padded)
		return rect
	return Rect2()

func overlaps(rect: Rect2) -> bool:
	# The fixed 22px label (26px with padding) touches at most two 32px strips.
	# Avoid constructing range/default arrays for every rejected candidate.
	var first := floori(rect.position.y/32)
	var last := floori(rect.end.y/32)
	if label_bands.has(first):
		for occupied: Rect2 in label_bands[first]:
			if occupied.intersects(rect): return true
	if last!=first and label_bands.has(last):
		for occupied: Rect2 in label_bands[last]:
			if occupied.intersects(rect): return true
	return false

func refresh_drop_order(world: GameWorld) -> void:
	ordered_drops = world.visible_drop_indices()
	ordered_drops.sort_custom(func(a,b):
		var left := int(world.drops[a].item.rarity)
		var right := int(world.drops[b].item.rarity)
		return left>right if left!=right else a<b)
	cached_count = world.drops.size()
	order_dirty = false

func draw_label(text: String, at: Vector2, color: Color, selected: bool = false) -> Rect2:
	var rect := place(text,at)
	if not rect.has_area(): return rect
	draw_rect(rect,Color("10201ee8"))
	draw_rect(rect,UIStyle.PAPER if selected else Color(color,.55),false,1)
	draw_string(ThemeDB.fallback_font,rect.position+Vector2(6,15),text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,color)
	return rect

func _draw() -> void:
	var stamp := CombatProfiler.start()
	begin_layout()
	if not is_instance_valid(session.world): return
	var world: GameWorld = session.world
	var markers := world.interaction_markers()
	for at in markers: draw_label(markers[at],project(at),UIStyle.PAPER)
	var selected := world.pickup_candidate()
	if order_dirty or cached_count!=world.drops.size(): refresh_drop_order(world)
	var count := 0
	if selected>=0 and draw_drop(selected,true): count += 1
	for index in ordered_drops:
		if index==selected: continue
		if draw_drop(index,false): count += 1
		if count>=64: break
	CombatProfiler.finish("world_labels.draw",stamp)

func draw_drop(index: int, selected: bool) -> bool:
	var drop: Dictionary = session.world.drops[index]
	var at := project(drop.at)-Vector2(0,30)
	if not Rect2(Vector2.ZERO,size).has_point(at): return false
	var text := tr(Database.items[drop.item.base].name_key)
	if selected: text = Settings.inputs.label("interact")+" · "+text
	var rect := draw_label(text,at,COLORS[clampi(int(drop.item.rarity),0,3)],selected)
	if rect.has_area(): drop_regions.append({"rect":rect,"index":index,"item":drop.item})
	return true
