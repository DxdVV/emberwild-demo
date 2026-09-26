class_name StatusHover extends PanelContainer

var state_ref: WeakRef
var effect_id: String
var description: Label
var refresh_remaining: float = 0

func _ready() -> void:
	theme = UIStyle.theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	description = UIStyle.label("",12)
	description.custom_minimum_size.x = 300
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(description)
	refresh()

func _process(delta: float) -> void:
	refresh_remaining -= delta
	if refresh_remaining<=0:
		refresh_remaining = .1
		refresh()

func refresh() -> void:
	var state: CombatState = state_ref.get_ref() if state_ref!=null else null
	if state==null:
		hide()
		return
	description.text = describe(state_ref,effect_id)+"\n\n"+tr("hud.inspect_hint")

static func describe(reference: WeakRef, id: String) -> String:
	var state: CombatState = reference.get_ref() if reference!=null else null
	if state==null: return ""
	if id=="shield" and state.health.shield>0: return TooltipPresenter.t("hud.shield_detail")%state.health.shield
	if state.statuses.entries.has(id):
		var entry: Dictionary = state.statuses.entries[id]
		return TooltipPresenter.t(entry.definition.name_key)+"\n"+TooltipPresenter.status_text(entry,state)
	return TooltipPresenter.t("hud.effect_expired")
