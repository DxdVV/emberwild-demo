class_name ItemComparison extends RefCounted

static func fill(parent: VBoxContainer, candidate: Dictionary, previous: Dictionary, state: CombatState, ability: AbilityData) -> void:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation",18)
	parent.add_child(columns)
	for entry in [["compare.current",previous],["compare.candidate",candidate]]:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(column)
		column.add_child(UIStyle.label(TooltipPresenter.t(entry[0]),14,UIStyle.GOLD))
		var item: Dictionary = entry[1]
		if item.is_empty(): PartyDetails.wrapped(column,TooltipPresenter.t("compare.empty"))
		else:
			PartyDetails.wrapped(column,TooltipPresenter.t(Database.items[item.base].name_key),UIStyle.PAPER)
			PartyDetails.wrapped(column,TooltipPresenter.item_text(item))
	parent.add_child(HSeparator.new())
	PartyDetails.wrapped(parent,TooltipPresenter.t("compare.context"),UIStyle.GOLD)
	var values := TooltipPresenter.item_comparison(candidate,state,ability)
	if values.stats.is_empty(): PartyDetails.wrapped(parent,TooltipPresenter.t("compare.no_stats"))
	for row in values.stats:
		PartyDetails.wrapped(parent,"%s: %s → %s (%s)"%[TooltipPresenter.t("stat."+row.id),TooltipPresenter.stat_value(row.id,row.before),TooltipPresenter.stat_value(row.id,row.after),TooltipPresenter.stat_value(row.id,row.delta,true)],UIStyle.GREEN if row.delta>0 else Color("f28f7b"))
	for key in ["projectiles","chains"]:
		if values.before_mods[key]!=values.after_mods[key]:
			PartyDetails.wrapped(parent,TooltipPresenter.t("compare."+key)%[values.before_mods[key],values.after_mods[key]],UIStyle.PAPER)
	if ability!=null:
		parent.add_child(HSeparator.new())
		PartyDetails.wrapped(parent,TooltipPresenter.t(ability.name_key),UIStyle.GOLD)
		PartyDetails.wrapped(parent,TooltipPresenter.t("compare.ability")%[values.before_ability.damage,values.after_ability.damage,values.before_ability.cooldown,values.after_ability.cooldown])
		PartyDetails.wrapped(parent,TooltipPresenter.t("compare.ability_note"))
