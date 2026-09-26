class_name InputBindings extends RefCounted

const KEYS := {"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"move_up":[KEY_W,KEY_UP],"move_down":[KEY_S,KEY_DOWN],"dodge":[KEY_SPACE],"ability_one":[KEY_Q],"ability_two":[KEY_E],"capture":[KEY_F],"interact":[KEY_R],"inventory":[KEY_I],"party":[KEY_TAB],"potion":[KEY_C],"swap_one":[KEY_1],"swap_two":[KEY_2],"swap_three":[KEY_3],"swap_four":[KEY_4],"pause":[KEY_ESCAPE],"debug_menu":[KEY_F3],"companion_mode":[KEY_T],"save_game":[KEY_F5],"load_game":[KEY_F9],"show_all_loot":[KEY_ALT]}
var bindings: Dictionary = {}

func defaults() -> Dictionary:
	var result := {}
	for action in KEYS:
		result[action] = []
		for key in KEYS[action]: result[action].append({"kind":"key","code":key})
	for index in 4: result["swap_second_"+str(index+1)] = [{"kind":"key","code":KEY_1+index,"shift":true}]
	result.attack = [{"kind":"mouse","code":MOUSE_BUTTON_LEFT}]
	result.focus = [{"kind":"mouse","code":MOUSE_BUTTON_RIGHT}]
	return result

func reset() -> void:
	bindings = defaults()
	apply()

static func from_event(event: InputEvent) -> Dictionary:
	var result := {}
	if event is InputEventKey:
		if not event.pressed or event.echo: return {}
		var code: int = event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if code==0: return {}
		result = {"kind":"key","code":code}
		if code in [KEY_SHIFT,KEY_CTRL,KEY_ALT,KEY_META]: return result
	elif event is InputEventMouseButton:
		if not event.pressed or event.button_index not in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE,MOUSE_BUTTON_XBUTTON1,MOUSE_BUTTON_XBUTTON2]: return {}
		result = {"kind":"mouse","code":event.button_index}
	else: return {}
	for key in ["shift","ctrl","alt","meta"]:
		if event.get(key+"_pressed"): result[key] = true
	return result

static func valid(value) -> bool:
	if not value is Dictionary or value.get("kind") not in ["key","mouse"] or not CombatSaveSchema.integer(value.get("code"),1,KEY_UNKNOWN-1): return false
	if value.kind=="mouse" and value.code not in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE,MOUSE_BUTTON_XBUTTON1,MOUSE_BUTTON_XBUTTON2]: return false
	for key in ["shift","ctrl","alt","meta"]:
		if value.has(key) and not value[key] is bool: return false
	return true

static func signature(value: Dictionary) -> String:
	return "%s:%s:%s:%s:%s:%s"%[value.kind,value.code,value.get("shift",false),value.get("ctrl",false),value.get("alt",false),value.get("meta",false)]

static func event_for(value: Dictionary) -> InputEvent:
	var event: InputEventWithModifiers
	if value.kind=="key":
		event = InputEventKey.new()
		event.physical_keycode = int(value.code)
	else:
		event = InputEventMouseButton.new()
		event.button_index = int(value.code)
	for key in ["shift","ctrl","alt","meta"]: event.set(key+"_pressed",value.get(key,false))
	return event

func conflicts(action: String, slot: int, value: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for other in bindings:
		for index in bindings[other].size():
			if other==action and index==slot: continue
			if signature(bindings[other][index])==signature(value): result.append(other)
	return result

func assign(action: String, slot: int, value: Dictionary) -> bool:
	if not bindings.has(action) or slot<0 or slot>bindings[action].size() or slot>1 or not valid(value): return false
	if value.kind=="key" and int(value.code)==KEY_ESCAPE and action!="pause": return false
	if not conflicts(action,slot,value).is_empty(): return false
	if slot==bindings[action].size(): bindings[action].append(value.duplicate())
	else: bindings[action][slot] = value.duplicate()
	apply()
	return true

func remove(action: String, slot: int) -> bool:
	if not bindings.has(action) or bindings[action].size()<2 or slot<0 or slot>=bindings[action].size(): return false
	bindings[action].remove_at(slot)
	apply()
	return true

func restore(data) -> bool:
	var candidate := defaults()
	if not data is Dictionary:
		reset()
		return false
	for action in candidate:
		if data.has(action): candidate[action] = data[action]
	var used := {}
	for action in candidate:
		var values = candidate[action]
		if not values is Array or values.is_empty() or values.size()>2:
			reset()
			return false
		for value in values:
			if not valid(value) or (value.kind=="key" and int(value.code)==KEY_ESCAPE and action!="pause"):
				reset()
				return false
			var id := signature(value)
			if used.has(id):
				reset()
				return false
			used[id] = true
	bindings = candidate.duplicate(true)
	apply()
	return true

func apply() -> void:
	for action in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		Input.action_release(action)
		InputMap.action_erase_events(action)
		for value in bindings[action]: InputMap.action_add_event(action,event_for(value))

static func display(value: Dictionary) -> String:
	var parts: Array[String] = []
	for modifier in ["ctrl","alt","shift","meta"]:
		if value.get(modifier,false): parts.append(modifier.capitalize())
	if value.kind=="key": parts.append(OS.get_keycode_string(int(value.code)))
	else: parts.append(TranslationServer.translate("input.mouse."+str(value.code)))
	return "+".join(parts)

func label(action: String, slot: int = 0) -> String:
	return display(bindings[action][slot]) if bindings.has(action) and slot<bindings[action].size() else "—"

func hint(action: String) -> String:
	var labels: Array[String] = []
	for value in bindings.get(action,[]): labels.append(display(value))
	return " / ".join(labels)
