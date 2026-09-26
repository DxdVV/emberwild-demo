class_name StatusStrip extends Control

signal inspect_requested

const BADGE_WIDTH := 30
const BADGE_TOP := 17
const BADGE_HEIGHT := 32
var state_ref: WeakRef
var owner_name: String = ""
var target: bool = false
var badges: Array[Dictionary] = []
var signature: Array = []
var heading: String = ""
var requested_effect: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

# Called by the existing HUD refresh, not an additional per-actor process loop.
func refresh(state: CombatState, title: String, show_target: bool = false) -> void:
	state_ref = weakref(state) if state!=null else null
	owner_name = title
	target = show_target
	badges.clear()
	if state==null:
		hide()
		return
	if state.health.shield>0:
		badges.append({"id":"shield","rows":StatusGlyph.SHIELD,"color":Color("9ed7e9"),"value":str(ceili(state.health.shield)),"stacks":1})
	var ids := state.statuses.entries.keys()
	ids.sort() # Stable position across refreshes, saves and reapplication.
	for id in ids:
		var entry: Dictionary = state.statuses.entries[id]
		var definition: StatusData = entry.definition
		badges.append({"id":str(id),"rows":definition.icon_rows,"color":definition.color,"value":duration_text(entry.remaining),"stacks":entry.stacks})
	heading = title
	if target: heading += "  %d / %d"%[ceili(state.health.current),ceili(state.health.maximum)]
	visible = target or not badges.is_empty()
	# Signature contains only visible values; combat state and RNG remain untouched.
	var next: Array = [heading]
	for badge in badges: next.append_array([badge.id,badge.value,badge.stacks])
	if next!=signature:
		signature = next
		queue_redraw()

static func duration_text(seconds: float) -> String:
	return "%.1f"%maxf(.1,ceilf(seconds*10)/10) if seconds<10 else str(ceili(seconds))

func badge_at(at: Vector2) -> int:
	if at.y<BADGE_TOP or at.y>=BADGE_TOP+BADGE_HEIGHT or at.x<0: return -1
	var index := int(at.x)/BADGE_WIDTH
	return index if index<badges.size() else -1

func _has_point(at: Vector2) -> bool:
	return badge_at(at)>=0

func _get_tooltip(at: Vector2) -> String:
	var index := badge_at(at)
	return badges[index].id if index>=0 else ""

func _make_custom_tooltip(for_text: String) -> Object:
	var hover := StatusHover.new()
	hover.state_ref = state_ref
	hover.effect_id = for_text
	return hover

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and badge_at(event.position)>=0:
		requested_effect = badges[badge_at(event.position)].id
		accept_event()
		inspect_requested.emit()
		requested_effect = ""

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var width := minf(size.x,maxf(badges.size()*BADGE_WIDTH,font.get_string_size(heading,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x+10))
	draw_rect(Rect2(0,0,width,15),Color("10201ee8"))
	draw_string(font,Vector2(5,11),heading,HORIZONTAL_ALIGNMENT_LEFT,width-10,11,UIStyle.PAPER)
	for index in badges.size():
		var badge: Dictionary = badges[index]
		var at := Vector2(index*BADGE_WIDTH,BADGE_TOP)
		draw_rect(Rect2(at,Vector2(BADGE_WIDTH-2,BADGE_HEIGHT)),Color("10201ef5"))
		draw_rect(Rect2(at,Vector2(BADGE_WIDTH-2,BADGE_HEIGHT)),Color(badge.color,.65),false,1)
		StatusGlyph.draw(self,badge.rows,at+Vector2(3,3),badge.color,2)
		if badge.stacks>1:
			draw_string(font,at+Vector2(19,13),str(badge.stacks),HORIZONTAL_ALIGNMENT_LEFT,-1,10,UIStyle.PAPER)
		draw_string(font,at+Vector2(3,28),badge.value,HORIZONTAL_ALIGNMENT_LEFT,-1,10,UIStyle.PAPER)
