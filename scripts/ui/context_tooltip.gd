class_name ContextTooltip extends PanelContainer

# One UI overlay; providers are evaluated only for the current hover/focus owner.
const PROVIDER := &"context_description"
const IDENTITY := &"context_identity"
const DELAY := .35
var description: Label
var modal: Control
var navigation: ModalFocus
var hover_fallback: Callable
var source_ref: WeakRef
var source_identity: String = ""
var keyboard: bool = false
var elapsed: float = 0
var refresh_remaining: float = 0

static func bind(control: Control, provider: Callable, focusable: bool = true) -> void:
	var first := not control.has_meta(PROVIDER)
	control.set_meta(PROVIDER,provider)
	control.tooltip_text = ""
	control.mouse_filter = Control.MOUSE_FILTER_PASS
	if focusable: control.focus_mode = Control.FOCUS_ALL
	if first and focusable and (control is Label or control is TextureRect):
		control.focus_entered.connect(control.queue_redraw)
		control.focus_exited.connect(control.queue_redraw)
		control.draw.connect(func():
			if control.has_focus(): control.draw_rect(Rect2(Vector2.ONE,control.size-Vector2(2,2)),UIStyle.GOLD,false,1))

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	add_theme_stylebox_override("panel",UIStyle.box(Color("10201efc"),UIStyle.GOLD))
	description = UIStyle.label("",12)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(description)
	# ModalFocus consumes Tab before later _input handlers. Follow GUI focus too.
	get_viewport().gui_focus_changed.connect(func(_control: Control): keyboard = true)
	hide()

func _input(event: InputEvent) -> void:
	# Gameplay keys (movement/reveal/pickup) do not replace mouse hover with an old focus.
	# Keyboard/controller navigation is observed through gui_focus_changed instead.
	if event is InputEventMouseMotion or event is InputEventMouseButton: keyboard = false

func clear() -> void:
	source_ref = null
	source_identity = ""
	elapsed = 0
	hide()

func eligible(control: Control) -> bool:
	if not is_instance_valid(control) or not control.is_inside_tree() or not control.is_visible_in_tree(): return false
	if is_instance_valid(modal) and modal.visible and not modal.is_ancestor_of(control): return false
	if control is BaseButton and control.disabled: return false
	return visible_rect(control).has_area()

func visible_rect(control: Control) -> Rect2:
	var rect := control.get_global_rect().intersection(get_viewport_rect())
	var parent := control.get_parent()
	while parent is Control:
		if parent.clip_contents: rect = rect.intersection(parent.get_global_rect())
		parent = parent.get_parent()
	return rect

func candidate() -> Control:
	if Settings.input_blocked(): return null
	if is_instance_valid(modal) and modal.visible and is_instance_valid(navigation) and navigation.popup_open(modal): return null
	var control := get_viewport().gui_get_focus_owner() if keyboard else get_viewport().gui_get_hovered_control()
	var hovered := control
	while is_instance_valid(control):
		if control.has_meta(PROVIDER): return control if eligible(control) else null
		control = control.get_parent_control()
	# Rendered labels can appear below a stationary pointer without a GUI motion event.
	if not keyboard and hover_fallback.is_valid():
		control = hover_fallback.call(hovered)
		if eligible(control): return control
	return null

func _process(delta: float) -> void:
	refresh_remaining -= delta
	if refresh_remaining>0: return
	var step := .1-refresh_remaining
	refresh_remaining = .1
	var next := candidate()
	if next==null: clear(); return
	var previous: Control = source_ref.get_ref() if source_ref!=null else null
	var identity := str(next.get_meta(IDENTITY,next.get_instance_id()))
	if next!=previous or identity!=source_identity:
		clear()
		source_ref = weakref(next)
		source_identity = identity
		return
	elapsed += step
	if elapsed<DELAY: return
	var provider: Callable = next.get_meta(PROVIDER)
	if not provider.is_valid(): clear(); return
	var content: String = provider.call()
	if content.is_empty(): hide(); return
	description.text = content
	custom_minimum_size.x = minf(340,get_viewport_rect().size.x-16)
	# Reset height when a replacement description becomes shorter.
	size = Vector2(custom_minimum_size.x,0)
	show()
	place.call_deferred()

func place() -> void:
	var source: Control = source_ref.get_ref() if source_ref!=null else null
	if not eligible(source): clear(); return
	var rect := visible_rect(source)
	var bounds := get_viewport_rect().grow(-8)
	var at := Vector2(rect.end.x+10,rect.position.y)
	if at.x+size.x>bounds.end.x:
		at.x = rect.position.x-size.x-10
	if at.x<bounds.position.x:
		at = Vector2(rect.position.x,rect.end.y+8)
		if at.y+size.y>bounds.end.y: at.y = rect.position.y-size.y-8
	position = Vector2(clampf(at.x,bounds.position.x,maxf(bounds.position.x,bounds.end.x-size.x)),clampf(at.y,bounds.position.y,maxf(bounds.position.y,bounds.end.y-size.y))).floor()
