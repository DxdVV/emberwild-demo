class_name PartyDetails extends RefCounted

static func wrapped(parent: Control, text: String, color: Color = UIStyle.MUTED) -> Label:
	var label := UIStyle.label(text,12,color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

static func fill(parent: VBoxContainer, creature: CreatureInstance, changed: Callable, expanded: bool = false) -> void:
	var species: SpeciesData = Database.species[creature.species_id]
	var state := creature.ensure_combat()
	var held := TooltipPresenter.t("ui.no_item") if creature.held_item.is_empty() else TooltipPresenter.t(Database.items[creature.held_item.base].name_key)
	var held_label := wrapped(parent,held,UIStyle.GOLD)
	if not creature.held_item.is_empty(): ContextTooltip.bind(held_label,func(): return TooltipPresenter.item_summary(creature.held_item))
	var names: Array[String] = []
	for id in species.passives+creature.traits:
		if Database.traits.has(str(id)): names.append(TooltipPresenter.t(Database.traits[str(id)].name_key))
	wrapped(parent," · ".join(names),UIStyle.GREEN)
	var details := VBoxContainer.new()
	details.visible = expanded
	var toggle := UIStyle.button(TooltipPresenter.t("ui.skill_details")%TooltipPresenter.t(Database.abilities[creature.abilities[1]].name_key),func(): details.visible = not details.visible)
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle.clip_text = true
	ContextTooltip.bind(toggle,func(): return TooltipPresenter.t(Database.abilities[creature.abilities[1]].name_key)+"\n"+TooltipPresenter.ability_text(Database.abilities[creature.abilities[1]],state))
	parent.add_child(toggle)
	parent.add_child(details)
	parent = details
	for id in species.passives+creature.traits:
		var definition: TraitData = Database.traits.get(str(id))
		if definition==null: continue
		wrapped(parent,TooltipPresenter.t("ui.trait" if definition.category==&"individual" else "ui.passive")+": "+TooltipPresenter.t(definition.name_key),UIStyle.GREEN)
		wrapped(parent,TooltipPresenter.trait_text(definition))
	wrapped(parent,TooltipPresenter.t("ui.command"),UIStyle.PAPER)
	var selection := OptionButton.new()
	selection.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection.clip_text = true
	var available := Progression.available_abilities(creature)
	available.erase(species.abilities[0])
	for index in available.size():
		var ability: AbilityData = Database.abilities[available[index]]
		selection.add_item(TooltipPresenter.t(ability.name_key))
		selection.get_popup().set_item_tooltip(index,TooltipPresenter.ability_text(ability,state))
		if available[index]==creature.abilities[1]: selection.select(index)
	selection.item_selected.connect(func(index):
		if Progression.select_command(creature,str(available[index])): changed.call())
	parent.add_child(selection)
	wrapped(parent,TooltipPresenter.ability_text(Database.abilities[creature.abilities[1]],state))
	for unlock in species.ability_unlocks:
		if creature.level<int(unlock.level): wrapped(parent,TooltipPresenter.t("ui.unlock")%[unlock.level,TooltipPresenter.t(Database.abilities[unlock.ability].name_key)],UIStyle.GOLD)
