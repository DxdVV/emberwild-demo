class_name StatusInspector extends RefCounted

static func fill(parent: VBoxContainer, state: CombatState, preferred: String = "") -> Control:
	PartyDetails.wrapped(parent,TooltipPresenter.t("status.vitals")%[state.health.current,state.health.maximum,state.health.shield,state.energy.current],UIStyle.PAPER)
	var stats: Array[String] = []
	for id in ["attack","defense","speed","critical_chance"]:
		stats.append(TooltipPresenter.t("stat."+id)+": "+TooltipPresenter.stat_value(id,state.stats.value(id)))
	PartyDetails.wrapped(parent," · ".join(stats))
	parent.add_child(HSeparator.new())
	var preferred_control: Control
	var reference: WeakRef = weakref(state)
	if state.health.shield>0:
		var label := effect_heading(parent,"shield",TooltipPresenter.t("status.shield"),StatusGlyph.SHIELD,Color("9ed7e9"),reference)
		if preferred=="shield": preferred_control = label
		PartyDetails.wrapped(parent,StatusHover.describe(reference,"shield"),UIStyle.PAPER)
		parent.add_child(HSeparator.new())
	if state.statuses.entries.is_empty() and state.health.shield<=0: PartyDetails.wrapped(parent,TooltipPresenter.t("status.empty"),UIStyle.GREEN)
	var ids := state.statuses.entries.keys()
	ids.sort() # Match the live badge order, including the shield first.
	for id in ids:
		var entry: Dictionary = state.statuses.entries[id]
		var definition: StatusData = entry.definition
		var label := effect_heading(parent,str(id),TooltipPresenter.t(definition.name_key),definition.icon_rows,definition.color,reference)
		if preferred==str(id): preferred_control = label
		PartyDetails.wrapped(parent,TooltipPresenter.status_text(entry,state),UIStyle.PAPER)
		parent.add_child(HSeparator.new())
	return preferred_control

static func effect_heading(parent: VBoxContainer, id: String, title: String, rows: Array[String], color: Color, reference: WeakRef) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(18,18)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func(): StatusGlyph.draw(icon,rows,Vector2(2,2),color,2))
	row.add_child(icon)
	var heading := UIStyle.label(title,16,color)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.set_meta("status_effect_id",id)
	ContextTooltip.bind(heading,StatusHover.describe.bind(reference,id))
	row.add_child(heading)
	parent.add_child(row)
	return heading
