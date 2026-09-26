class_name ModalFocus extends Node

# Tab order is read from the current visible tree, including rebuilt/expanded rows.
var panel: Control
var body: Control
var close_button: Button
var generation: int = 0
var preferred_focus: WeakRef

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func configure(content: Control, close: Button) -> void:
	body = content
	close_button = close
	preferred_focus = null
	generation += 1
	initial_focus.call_deferred(generation)

func controls() -> Array[Control]:
	var result: Array[Control] = []
	if not is_instance_valid(panel) or not panel.is_visible_in_tree(): return result
	collect(panel,result)
	# The primary content comes first; closing is still reachable in the same cycle.
	if is_instance_valid(close_button) and close_button in result:
		result.erase(close_button)
		result.append(close_button)
	return result

func collect(node: Node, result: Array[Control]) -> void:
	if node is Control:
		if not node.is_visible_in_tree(): return
		if node.focus_mode==Control.FOCUS_ALL and not node is ScrollBar:
			if not node is BaseButton or not node.disabled: result.append(node)
	for child in node.get_children(): collect(child,result)

func initial_focus(expected: int) -> void:
	# Containers finish sizing after deferred calls. Early focus scrolls to stale rects.
	await get_tree().process_frame
	await get_tree().process_frame
	if generation!=expected: return
	var available := controls()
	var preferred = preferred_focus.get_ref() if preferred_focus!=null else null
	if preferred in available: preferred.grab_focus()
	elif not available.is_empty(): available[0].grab_focus()

func popup_open(node: Node) -> bool:
	for child in node.get_children(true):
		if child is Popup and child.visible: return true
		if popup_open(child): return true
	return false

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed: return
	if event.keycode!=KEY_TAB and event.physical_keycode!=KEY_TAB: return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed or Settings.input_blocked(): return
	if not is_instance_valid(panel) or not panel.is_visible_in_tree() or popup_open(panel): return
	var available := controls()
	if available.is_empty(): return
	var index := available.find(get_viewport().gui_get_focus_owner())
	if index<0: index = 0 if event.shift_pressed else -1
	available[posmod(index+(-1 if event.shift_pressed else 1),available.size())].grab_focus()
	get_viewport().set_input_as_handled()
