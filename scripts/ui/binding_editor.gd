class_name BindingEditor extends VBoxContainer

var action: String = ""
var slot: int = 0
var modifier_event: InputEventKey
var status: Label
var rows: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	status = PartyDetails.wrapped(self,tr("input.help"))
	rows = VBoxContainer.new()
	add_child(rows)
	add_child(UIStyle.button(tr("input.reset"),func(): cancel(); Settings.inputs.reset(); save(); rebuild()))
	rebuild()

func rebuild() -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	for id in Settings.inputs.bindings:
		if id=="debug_menu" and not OS.is_debug_build(): continue
		var row := HBoxContainer.new()
		var name_label := UIStyle.label(tr("input."+str(id)),12)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name_label)
		for index in 2:
			var button := UIStyle.button(Settings.inputs.label(id,index),func(): begin_capture(id,index))
			button.custom_minimum_size.x = 105
			button.clip_text = true
			button.tooltip_text = Settings.inputs.label(id,index)
			row.add_child(button)
			var clear := UIStyle.button("×",func():
				if Settings.inputs.remove(id,index): save(); rebuild())
			clear.disabled = Settings.inputs.bindings[id].size()<2 or index>=Settings.inputs.bindings[id].size()
			clear.custom_minimum_size.x = 36
			clear.tooltip_text = tr("input.remove")
			row.add_child(clear)
		rows.add_child(row)

func begin_capture(id: String, index: int) -> void:
	action = id
	slot = index
	modifier_event = null
	Settings.capturing_input = true
	status.text = tr("input.capture_prompt")%tr("input."+id)

func cancel() -> void:
	action = ""
	modifier_event = null
	Settings.capturing_input = false
	Settings.block_input_frames = Engine.get_process_frames()+2
	if is_instance_valid(status): status.text = tr("input.help")

func _exit_tree() -> void:
	if not action.is_empty(): cancel()

func _input(event: InputEvent) -> void:
	if action.is_empty(): return
	get_viewport().set_input_as_handled()
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode else event.keycode
		if code==KEY_ESCAPE and event.pressed:
			cancel()
			return
		if code in [KEY_SHIFT,KEY_CTRL,KEY_ALT,KEY_META]:
			if event.pressed: modifier_event = event.duplicate()
			elif modifier_event!=null: capture_event(modifier_event)
			return
	capture_event(event)

func capture_event(event: InputEvent) -> void:
	var value := InputBindings.from_event(event)
	if value.is_empty(): return
	var conflicts := Settings.inputs.conflicts(action,slot,value)
	if not conflicts.is_empty():
		var names: Array[String] = []
		for id in conflicts: names.append(tr("input."+id))
		status.text = tr("input.conflict")%", ".join(names)
		modifier_event = null
		return
	if not Settings.inputs.assign(action,slot,value): return
	cancel()
	save()
	rebuild()

func save() -> void:
	if Settings.persist()!=OK: status.text = tr("settings.save_failed")
