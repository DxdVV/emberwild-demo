class_name GameHUD extends CanvasLayer

var session
var root: Control
var panel: PanelContainer
var panel_content: VBoxContainer
var shade: ColorRect
var fade_rect: ColorRect
var header: Label
var region: Label
var objectives: Label
var health: ProgressBar
var health_text: Label
var energy: ProgressBar
var companion_row: HBoxContainer
var resources_label: Label
var notification: Label
var notification_remaining: float = 0
var minimap: MinimapView
var boss_health: ProgressBar
var boss_label: Label
var skill_labels: Array[Label] = []
var refresh_remaining: float = 0
var equip_target: int = 0
var debug_console
var party_card_signature: Array[String] = []
var party_card_details: Array[Label] = []
var party_expanded_id: String = ""
var control_hint: Label
var binding_editor: BindingEditor
var world_labels: WorldLabels
var pending_defeat: WeakRef
var status_strips: Array[StatusStrip] = []
var focus_status: StatusStrip
var panel_rebuild: Callable
var modal_focus: ModalFocus
var translation_pending: bool = false
var locale_save_error: bool = false
var panel_notice: Label
var context_tooltip: ContextTooltip

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIStyle.theme()
	add_child(root)
	world_labels = WorldLabels.new()
	world_labels.session = session
	root.add_child(world_labels)
	var brand := UIStyle.label("E M B E R W I L D",12,UIStyle.GOLD)
	brand.position = Vector2(24,17)
	root.add_child(brand)
	header = UIStyle.label("",25)
	header.position = Vector2(23,35)
	root.add_child(header)
	region = UIStyle.label("",11,UIStyle.MUTED)
	region.position = Vector2(24,68)
	root.add_child(region)
	objectives = UIStyle.label("",12,UIStyle.PAPER)
	objectives.position = Vector2(25,109)
	objectives.add_theme_color_override("font_shadow_color",Color("0a1815"))
	objectives.add_theme_constant_override("shadow_offset_x",1)
	objectives.add_theme_constant_override("shadow_offset_y",1)
	root.add_child(objectives)
	minimap = MinimapView.new()
	minimap.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	minimap.position = Vector2(-167,19)
	minimap.size = Vector2(143,92)
	root.add_child(minimap)
	resources_label = UIStyle.label("",12,UIStyle.GOLD)
	resources_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	resources_label.position = Vector2(-169,117)
	root.add_child(resources_label)
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -83
	bottom.offset_bottom = -14
	bottom.offset_left = 24
	bottom.offset_right = -24
	bottom.add_theme_stylebox_override("panel",UIStyle.box(Color(.04,.1,.085,.95),Color("566249")))
	root.add_child(bottom)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	bottom.add_child(row)
	var bars := VBoxContainer.new()
	bars.custom_minimum_size = Vector2(166,0)
	row.add_child(bars)
	health_text = UIStyle.label(tr("compare.trainer_name"),12)
	bars.add_child(health_text)
	health = progress_bar(Color("b7594c"),10)
	bars.add_child(health)
	energy = progress_bar(Color("5aada3"),5)
	bars.add_child(energy)
	companion_row = HBoxContainer.new()
	companion_row.custom_minimum_size = Vector2(260,0)
	companion_row.add_theme_constant_override("separation",12)
	row.add_child(companion_row)
	for action in ["ability_one","ability_two","capture","potion"]:
		var skill := UIStyle.label(Settings.inputs.label(action),12,UIStyle.PAPER)
		skill.custom_minimum_size.x = 114 if skill_labels.size()<2 else 50
		skill.clip_text = true
		skill.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		skill_labels.append(skill)
		if skill_labels.size()<=2:
			var slot := skill_labels.size()-1
			ContextTooltip.bind(skill,func(): return skill_tooltip(slot))
		row.add_child(skill)
	var menu := UIStyle.button("≡",show_pause)
	row.add_child(menu)
	control_hint = UIStyle.label("",11,UIStyle.MUTED)
	control_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	control_hint.offset_top = -15
	control_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	control_hint.clip_text = true
	control_hint.mouse_filter = Control.MOUSE_FILTER_PASS
	control_hint.add_theme_color_override("font_shadow_color",Color.BLACK)
	control_hint.add_theme_constant_override("shadow_outline_size",3)
	root.add_child(control_hint)
	Settings.changed.connect(refresh_control_hints)
	refresh_control_hints()
	notification = UIStyle.label("",15,UIStyle.GOLD)
	notification.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notification.position = Vector2(-340,170)
	notification.size = Vector2(680,35)
	notification.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification.add_theme_color_override("font_shadow_color",Color.BLACK)
	notification.add_theme_constant_override("shadow_outline_size",6)
	root.add_child(notification)
	boss_health = progress_bar(Color("ab6752"),8)
	boss_health.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_health.position = Vector2(-160,45)
	boss_health.size = Vector2(320,8)
	root.add_child(boss_health)
	boss_label = UIStyle.label("",13,UIStyle.GOLD)
	boss_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_label.position = Vector2(-160,21)
	boss_label.size = Vector2(320,20)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(boss_label)
	for index in 3:
		var strip := StatusStrip.new()
		strip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		strip.position = Vector2(24+index*304,-137)
		strip.size = Vector2(288,49)
		strip.hide()
		strip.inspect_requested.connect(func(): inspect_active_status(index))
		status_strips.append(strip)
		root.add_child(strip)
	focus_status = StatusStrip.new()
	focus_status.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	focus_status.position = Vector2(-150,65)
	focus_status.size = Vector2(300,49)
	focus_status.hide()
	focus_status.inspect_requested.connect(func(): inspect_strip(focus_status))
	root.add_child(focus_status)
	shade = ColorRect.new()
	shade.color = Color(.015,.045,.04,.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = -230
	panel.offset_bottom = 225
	root.add_child(panel)
	modal_focus = ModalFocus.new()
	modal_focus.panel = panel
	add_child(modal_focus)
	context_tooltip = ContextTooltip.new()
	context_tooltip.modal = panel
	context_tooltip.navigation = modal_focus
	context_tooltip.hover_fallback = world_labels.hover_target
	root.add_child(context_tooltip)
	fade_rect = ColorRect.new()
	fade_rect.color = Color("071914")
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.modulate.a = 0
	root.add_child(fade_rect)
	world_labels.reserve_controls([brand,header,region,objectives,minimap,resources_label,bottom,control_hint,notification,boss_label,boss_health,focus_status]+status_strips)
	close_panel()

func progress_bar(color: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = height
	bar.show_percentage = false
	var background := UIStyle.box(Color("101c1a"),Color("35463a"))
	var fill := UIStyle.box(color,color,0)
	for style in [background,fill]:
		style.content_margin_left = 0
		style.content_margin_right = 0
		style.content_margin_top = 0
		style.content_margin_bottom = 0
	bar.add_theme_stylebox_override("background",background)
	bar.add_theme_stylebox_override("fill",fill)
	return bar

func bind_world() -> void:
	header.text = tr(session.world.area.name_key)
	region.text = tr(session.world.area.subtitle_key)
	minimap.world = session.world
	refresh_party_cards()

func refresh_party_cards() -> void:
	var signature: Array[String] = []
	var creatures: Array[CreatureInstance] = []
	for index in session.party.active_indices:
		if index<0 or index>=session.party.roster.size(): continue
		var creature: CreatureInstance = session.party.roster[index]
		signature.append(creature.persistent_id+":"+creature.species_id+":"+TranslationServer.get_locale())
		creatures.append(creature)
	if signature!=party_card_signature:
		party_card_signature = signature
		party_card_details.clear()
		for child in companion_row.get_children():
			companion_row.remove_child(child)
			child.queue_free()
		for slot in creatures.size():
			var creature := creatures[slot]
			var species: SpeciesData = Database.species[creature.species_id]
			var card := HBoxContainer.new()
			ContextTooltip.bind(card,func(): return TooltipPresenter.creature_text(creature),false)
			var portrait := UIStyle.species_portrait(species,44)
			ContextTooltip.bind(portrait,func(): return TooltipPresenter.creature_text(creature))
			card.add_child(portrait)
			var text := VBoxContainer.new()
			text.add_child(UIStyle.label("%d · %s"%[slot+1,tr(species.name_key)],12,species.color))
			var detail := UIStyle.label("",10,UIStyle.MUTED)
			text.add_child(detail)
			party_card_details.append(detail)
			card.add_child(text)
			companion_row.add_child(card)
	for index in creatures.size():
		party_card_details[index].text = tr("hud.level")%[creatures[index].level,int(creatures[index].health_ratio*100)]

func _process(delta: float) -> void:
	if not is_instance_valid(session.world): return
	var stamp := CombatProfiler.start()
	var world: GameWorld = session.world
	health.max_value = world.trainer.health.maximum
	health.value = world.trainer.health.current
	health_text.text = tr("hud.health") % [health.value,health.max_value]
	energy.value = world.trainer.energy.current
	notification_remaining -= delta
	notification.visible = notification_remaining>0 and not panel.visible
	refresh_remaining -= delta
	if refresh_remaining>0:
		CombatProfiler.finish("hud",stamp)
		return
	# Text uses tenths of a second; bars remain responsive every rendered frame.
	refresh_remaining = .1
	resources_label.text = tr("hud.resources") % [session.inventory.currency,session.inventory.seals]
	objectives.text = tr("hud.objectives") % ["◆" if session.quest.get("capture",false) else "◇","◆" if session.quest.get("elite",false) else "◇","◆" if session.quest.get("boss",false) else "◇"]
	for index in 2:
		if index<session.party.active_actors.size():
			var actor = session.party.active_actors[index]
			if is_instance_valid(actor):
				var ability: AbilityData = Database.abilities[actor.ability_id(1)]
				var remaining: float = actor.abilities.cooldowns.remaining(ability.id)
				skill_labels[index].text = Settings.inputs.label("ability_one" if index==0 else "ability_two")+"\n"+(tr("hud.cooldown") % remaining if remaining>0 else tr(ability.name_key).strip_edges())
	var target = world.aim_target(world.trainer,Database.rules.capture_range)
	skill_labels[2].text = Settings.inputs.label("capture")+"\n"+("%d%%" % (world.capture.chance(target)*100) if target != null else tr("hud.capture"))
	skill_labels[3].text = Settings.inputs.label("potion")+"\n" + str(session.inventory.potions)
	var boss = world.actors.filter(func(actor): return actor.faction==Factions.Team.BOSS and actor.health.current>0 and actor.global_position.distance_to(world.trainer.global_position)<600)
	boss_health.visible = not boss.is_empty() and not panel.visible
	boss_label.visible = boss_health.visible
	if not boss.is_empty():
		boss_health.max_value = boss[0].health.maximum
		boss_health.value = boss[0].health.current
		boss_label.text = tr(boss[0].species.name_key)
	refresh_party_cards()
	refresh_status_strips()
	CombatProfiler.finish("hud",stamp)

func inspect_active_status(index: int) -> void:
	inspect_strip(status_strips[index])

func inspect_strip(strip: StatusStrip) -> void:
	var state = strip.state_ref.get_ref() if strip.state_ref!=null else null
	if state==null: return
	# A swap can precede the next HUD refresh. Resolve the displayed persistent
	# state, never reinterpret its badge using the new occupant of that active slot.
	if state==session.trainer_combat:
		show_statuses(-1,strip.requested_effect)
		return
	for index in session.party.roster.size():
		if session.party.roster[index].ensure_combat()==state:
			show_statuses(index,strip.requested_effect)
			return
	var focus = session.world.focus_target
	if is_instance_valid(focus) and focus.health.current>0 and focus.combat==state:
		show_statuses(-2,strip.requested_effect)
	else: refresh_status_strips()

func refresh_status_strips() -> void:
	if panel.visible or session.world.trainer.health.current<=0:
		for strip in status_strips: strip.hide()
		focus_status.hide()
		return
	status_strips[0].refresh(session.world.trainer.combat,tr("compare.trainer_name"))
	for slot in 2:
		if slot>=session.party.active_indices.size():
			status_strips[slot+1].refresh(null,"")
			continue
		var index: int = session.party.active_indices[slot]
		if index<0 or index>=session.party.roster.size():
			status_strips[slot+1].refresh(null,"")
			continue
		var creature: CreatureInstance = session.party.roster[index]
		status_strips[slot+1].refresh(creature.ensure_combat(),tr(Database.species[creature.species_id].name_key))
	var focus = session.world.focus_target
	if is_instance_valid(focus) and focus.health.current>0 and focus.visible and focus.global_position.distance_to(session.world.trainer.global_position)<=600:
		focus_status.refresh(focus.combat,tr("status.target")%tr(focus.species.name_key),true)
	else: focus_status.refresh(null,"")

func notify(text: String) -> void:
	notification.text = text
	notification_remaining = 4
	if is_instance_valid(panel_notice) and panel.visible:
		panel_notice.text = text
		panel_notice.show()

func refresh_control_hints() -> void:
	var movement: Array[String] = []
	for id in ["move_up","move_left","move_down","move_right"]: movement.append(Settings.inputs.label(id))
	control_hint.text = tr("input.footer")%["/".join(movement),Settings.inputs.label("attack"),Settings.inputs.label("dodge"),Settings.inputs.label("inventory"),Settings.inputs.label("party"),Settings.inputs.label("interact"),Settings.inputs.label("show_all_loot")]
	control_hint.tooltip_text = control_hint.text

func skill_tooltip(slot: int) -> String:
	if slot>=session.party.active_actors.size(): return ""
	var actor = session.party.active_actors[slot]
	if not is_instance_valid(actor): return ""
	var definition: AbilityData = Database.abilities[actor.ability_id(1)]
	return tr(definition.name_key)+"\n"+TooltipPresenter.ability_text(definition,actor.combat)

func _notification(what: int) -> void:
	if what==NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(header) and not translation_pending:
		translation_pending = true
		refresh_translation.call_deferred()

func refresh_translation() -> void:
	translation_pending = false
	if not is_instance_valid(session.world): return
	bind_world()
	refresh_control_hints()
	refresh_remaining = 0
	# Old transient sentences cannot be reformatted after their arguments are gone.
	notification_remaining = 0
	if panel.visible and panel_rebuild.is_valid(): panel_rebuild.call()

func open_panel(title: String, subtitle: String = "", rebuild: Callable = Callable()) -> VBoxContainer:
	context_tooltip.clear()
	panel_rebuild = rebuild
	if is_instance_valid(binding_editor) and not binding_editor.action.is_empty(): binding_editor.cancel()
	for child in panel.get_children():
		panel.remove_child(child)
		child.queue_free()
	shade.show()
	panel.show()
	for strip in status_strips: strip.hide()
	if is_instance_valid(focus_status): focus_status.hide()
	get_tree().paused = true
	Audio.duck(true)
	panel_content = VBoxContainer.new()
	panel_content.add_theme_constant_override("separation",10)
	panel.add_child(panel_content)
	var top := HBoxContainer.new()
	var heading := UIStyle.label(title,26,UIStyle.GOLD)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	var close := UIStyle.button("×",close_panel)
	ContextTooltip.bind(close,func(): return tr("menu.close"))
	top.add_child(close)
	panel_content.add_child(top)
	if not subtitle.is_empty(): PartyDetails.wrapped(panel_content,subtitle)
	panel_content.add_child(HSeparator.new())
	panel_notice = PartyDetails.wrapped(panel_content,"",UIStyle.GOLD)
	panel_notice.hide()
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	panel_content.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",9)
	scroll.add_child(content)
	modal_focus.configure(content,close)
	return content

func close_panel(allow_defeat: bool = false) -> void:
	if is_instance_valid(context_tooltip): context_tooltip.clear()
	if is_instance_valid(binding_editor) and not binding_editor.action.is_empty(): binding_editor.cancel()
	if not allow_defeat and is_instance_valid(session.world) and is_instance_valid(session.world.trainer) and session.world.trainer.health.current<=0:
		show_defeat()
		return
	pending_defeat = null
	if is_instance_valid(panel): panel.hide()
	var focused := get_viewport().gui_get_focus_owner()
	if is_instance_valid(focused) and panel.is_ancestor_of(focused): focused.release_focus()
	if is_instance_valid(shade): shade.hide()
	get_tree().paused = false
	Audio.duck(false)

func show_title() -> void:
	var body := open_panel("E M B E R W I L D",tr("menu.tagline"),show_title)
	var art := HBoxContainer.new()
	art.alignment = BoxContainer.ALIGNMENT_CENTER
	for cell in [1,0,2]: art.add_child(UIStyle.portrait(cell,115))
	body.add_child(art)
	var copy := UIStyle.label(tr("menu.intro"),16)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(copy)
	PartyDetails.wrapped(body,tr("demo.scope"),UIStyle.MUTED)
	body.add_child(UIStyle.button(tr("menu.start"),func(): close_panel(); notify(tr("input.camp_hint")%Settings.inputs.label("interact"))))
	if FileAccess.file_exists(SaveStore.storage_path) or FileAccess.file_exists(SaveStore.storage_path+".bak"): body.add_child(UIStyle.button(tr("menu.continue"),session.load_game))
	body.add_child(UIStyle.button(tr("menu.settings"),show_settings))

func show_pause() -> void:
	if is_instance_valid(session.world) and session.world.trainer.health.current<=0:
		show_defeat()
		return
	var body := open_panel(tr("menu.paused"),tr("menu.pause_hint"),show_pause)
	for entry in [[tr("menu.continue"),close_panel],[tr("menu.party"),show_party],[tr("menu.inventory"),show_inventory],[tr("menu.settings"),show_settings],[tr("menu.save"),session.save_game],[tr("menu.load"),session.load_game]]:
		body.add_child(UIStyle.button(entry[0],entry[1]))
	body.add_child(UIStyle.button(tr("status.title"),show_statuses))
	if session.demo_completed(): body.add_child(UIStyle.button(tr("demo.results"),show_demo_complete))
	body.add_child(UIStyle.button(tr("menu.quit"),session.request_exit))

func show_demo_complete(from_camp: bool = false) -> void:
	if not session.demo_completed():
		if from_camp: show_camp()
		else: show_pause()
		return
	var body := open_panel(tr("demo.title"),tr("demo.subtitle"),show_demo_complete.bind(from_camp))
	PartyDetails.wrapped(body,tr("demo.story"))
	PartyDetails.wrapped(body,tr("hud.objectives")%["◆","◆","◆"],UIStyle.GOLD)
	PartyDetails.wrapped(body,tr("demo.after"),UIStyle.MUTED)
	body.add_child(UIStyle.button(tr("demo.explore"),close_panel))
	if from_camp: body.add_child(UIStyle.button(tr("camp.title"),show_camp))
	body.add_child(UIStyle.button(tr("menu.quit"),session.request_exit))

func show_inventory() -> void:
	var body := open_panel(tr("menu.inventory"),tr("inventory.hint"),show_inventory)
	equip_target = clampi(equip_target,0,session.party.roster.size()-1)
	body.add_child(UIStyle.label(tr("compare.creature_owner"),12,UIStyle.MUTED))
	var target := OptionButton.new()
	for creature in session.party.roster: target.add_item(tr(Database.species[creature.species_id].name_key))
	target.select(clampi(equip_target,0,session.party.roster.size()-1))
	target.item_selected.connect(func(index): equip_target = index; show_inventory())
	body.add_child(target)
	for index in session.inventory.items.size():
		var item: Dictionary = session.inventory.items[index]
		var definition: ItemData = Database.items[item.base]
		var row := HBoxContainer.new()
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_child(UIStyle.label(tr(definition.name_key)+" · "+[tr("item.rarity.0"),tr("item.rarity.1"),tr("item.rarity.2"),tr("item.rarity.3")][clampi(item.rarity,0,3)],15,UIStyle.GOLD))
		var description := UIStyle.label(TooltipPresenter.item_text(item),12,UIStyle.MUTED)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ContextTooltip.bind(text,func(): return TooltipPresenter.item_summary(item),false)
		text.add_child(description)
		row.add_child(text)
		var actions := VBoxContainer.new()
		row.add_child(actions)
		var compare := UIStyle.button(tr("compare.action"),func(): show_item_comparison(index))
		ContextTooltip.bind(compare,func(): return TooltipPresenter.item_summary(item))
		actions.add_child(compare)
		var equip := UIStyle.button(tr("inventory.equip"),func(): session.equip(index,equip_target); show_inventory())
		ContextTooltip.bind(equip,func(): return TooltipPresenter.item_summary(item))
		actions.add_child(equip)
		if definition.category==&"trainer": PartyDetails.wrapped(text,tr("compare.trainer"))
		body.add_child(row)
		body.add_child(HSeparator.new())
	if session.inventory.items.is_empty(): body.add_child(UIStyle.label(tr("inventory.empty"),14,UIStyle.MUTED))
	var creature: CreatureInstance = session.party.roster[equip_target]
	if not creature.held_item.is_empty():
		var remove := UIStyle.button(tr("compare.remove")%tr(Database.items[creature.held_item.base].name_key),func():
			if not session.unequip_held(equip_target): notify(tr("compare.full"))
			show_inventory())
		ContextTooltip.bind(remove,func(): return TooltipPresenter.item_summary(creature.held_item))
		body.add_child(remove)
	for slot in session.equipment:
		var remove := UIStyle.button(tr("compare.remove")%tr(Database.items[session.equipment[slot].base].name_key),func():
			if not session.unequip_trainer(slot): notify(tr("compare.full"))
			show_inventory())
		ContextTooltip.bind(remove,func(): return TooltipPresenter.item_summary(session.equipment.get(slot,{})))
		body.add_child(remove)

func show_item_comparison(index: int) -> void:
	if index<0 or index>=session.inventory.items.size(): show_inventory(); return
	var item: Dictionary = session.inventory.items[index]
	var definition: ItemData = Database.items[item.base]
	var creature: CreatureInstance = session.party.roster[equip_target]
	var held := definition.category==&"held"
	var state: CombatState = creature.ensure_combat() if held else session.trainer_combat
	var previous: Dictionary = creature.held_item if held else session.equipment.get(str(definition.slot),{})
	var owner_name: String = tr(Database.species[creature.species_id].name_key) if held else tr("compare.trainer_name")
	var ability: AbilityData = Database.abilities[creature.abilities[1] if held else "ability.pulse"]
	var body := open_panel(tr("compare.title"),tr("compare.owner")%owner_name,show_item_comparison.bind(index))
	body.add_child(UIStyle.button(tr("compare.back"),show_inventory))
	ItemComparison.fill(body,item,previous,state,ability)
	panel_content.add_child(UIStyle.button(tr("compare.equip"),func(): session.equip(index,equip_target); show_inventory()))

func show_statuses(selected: int = -1, effect: String = "") -> void:
	var body := open_panel(tr("status.title"),tr("status.paused"),show_statuses.bind(selected,effect))
	var picker := OptionButton.new()
	picker.add_item(tr("compare.trainer_name"))
	for creature in session.party.roster: picker.add_item(tr(Database.species[creature.species_id].name_key))
	var focus = session.world.focus_target
	var has_focus: bool = is_instance_valid(focus) and focus.health.current>0
	if has_focus: picker.add_item(tr("status.target")%tr(focus.species.name_key))
	if selected==-2 and not has_focus: selected = -1
	picker.select(picker.item_count-1 if selected==-2 else selected+1)
	picker.item_selected.connect(func(index): show_statuses(-2 if has_focus and index==picker.item_count-1 else index-1))
	body.add_child(picker)
	var state: CombatState = session.trainer_combat
	if selected>=0 and selected<session.party.roster.size(): state = session.party.roster[selected].ensure_combat()
	elif selected==-2: state = focus.combat
	var preferred := StatusInspector.fill(body,state,effect)
	if preferred!=null: modal_focus.preferred_focus = weakref(preferred)

func show_party() -> void:
	var body := open_panel(tr("party.title"),tr("input.party_hint")%[Settings.inputs.label("ability_one"),Settings.inputs.label("ability_two")],show_party)
	body.add_child(UIStyle.button(tr("status.title"),show_statuses))
	for index in session.party.roster.size():
		var creature: CreatureInstance = session.party.roster[index]
		var species: SpeciesData = Database.species[creature.species_id]
		var row := HBoxContainer.new()
		var portrait := UIStyle.species_portrait(species,76)
		ContextTooltip.bind(portrait,func(): return TooltipPresenter.creature_text(creature))
		row.add_child(portrait)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_child(UIStyle.label(tr(species.name_key)+(" ✦" if creature.cosmetic else ""),17,species.color))
		text.add_child(UIStyle.label(tr("party.progress") % [creature.level,creature.xp,Progression.threshold(creature.level),creature.health_ratio*100],12,UIStyle.MUTED))
		PartyDetails.fill(text,creature,func(): party_expanded_id = creature.persistent_id; show_party(),party_expanded_id==creature.persistent_id)
		row.add_child(text)
		var actions := VBoxContainer.new()
		actions.add_child(UIStyle.button(tr("status.inspect")%creature.ensure_combat().statuses.entries.size(),func(): show_statuses(index)))
		if index in session.party.active_indices: actions.add_child(UIStyle.label(tr("party.active"),12,UIStyle.GREEN))
		else:
			for slot in 2: actions.add_child(UIStyle.button(tr("party.slot")%(slot+1),func(): session.party.swap(index,slot); show_party()))
		if creature.level>=species.evolution_level and not str(species.evolution_target).is_empty(): actions.add_child(UIStyle.button(tr("party.evolve"),func():
			session.party.evolve(index)
			show_party()))
		row.add_child(actions)
		body.add_child(row)
		body.add_child(HSeparator.new())

func show_settings() -> void:
	var body := open_panel(tr("menu.settings"),tr("settings.hint"),show_settings)
	var language_row := HBoxContainer.new()
	language_row.add_child(UIStyle.label(tr("settings.language"),14))
	var language := OptionButton.new()
	language.name = "LanguagePicker"
	language.add_item("Русский")
	language.add_item("English")
	language.select(0 if Settings.locale=="ru" else 1)
	language.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	language.item_selected.connect(func(index):
		locale_save_error = Settings.set_locale(["ru","en"][index])!=OK
		if not translation_pending: show_settings())
	language_row.add_child(language)
	body.add_child(language_row)
	if locale_save_error: PartyDetails.wrapped(body,tr("settings.save_failed"),UIStyle.GOLD)
	body.add_child(UIStyle.button(tr("input.title"),show_controls))
	body.add_child(UIStyle.button(tr("loot.title"),show_loot_filter))
	for bus in Settings.volumes:
		var row := HBoxContainer.new()
		var text := UIStyle.label(tr("audio."+bus),14)
		text.custom_minimum_size.x = 155
		row.add_child(text)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 1
		slider.step = .05
		slider.value = Settings.volumes[bus]
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(func(value): Settings.volumes[bus] = value; Settings.persist())
		row.add_child(slider)
		body.add_child(row)
	var quality := OptionButton.new()
	for name in [tr("settings.quality.0"),tr("settings.quality.1"),tr("settings.quality.2")]: quality.add_item(name)
	quality.select(Settings.effects_quality)
	quality.item_selected.connect(func(index): Settings.effects_quality = index; Settings.persist())
	body.add_child(quality)
	var shake := CheckButton.new()
	shake.text = tr("settings.shake")
	shake.button_pressed = Settings.shake
	shake.toggled.connect(func(value): Settings.shake=value; Settings.persist())
	body.add_child(shake)
	var fullscreen := CheckButton.new()
	fullscreen.text = tr("settings.fullscreen")
	fullscreen.button_pressed = DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen.toggled.connect(func(value):
		Settings.fullscreen = value
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)
		Settings.persist())
	body.add_child(fullscreen)

func show_controls() -> void:
	var body := open_panel(tr("input.title"),"",show_controls)
	body.add_child(UIStyle.button(tr("settings.back"),show_settings))
	binding_editor = BindingEditor.new()
	body.add_child(binding_editor)

func show_loot_filter() -> void:
	var body := open_panel(tr("loot.title"),"",show_loot_filter)
	body.add_child(UIStyle.button(tr("settings.back"),show_settings))
	body.add_child(LootFilterEditor.new())

func show_camp() -> void:
	var body := open_panel(tr("camp.title"),tr("camp.hint"),show_camp)
	if session.demo_completed(): body.add_child(UIStyle.button(tr("demo.results"),show_demo_complete.bind(true)))
	body.add_child(UIStyle.label(tr("camp.currency")%session.inventory.currency,16,UIStyle.GOLD))
	body.add_child(UIStyle.button(tr("camp.seals"),func():
		if session.inventory.currency>=15: session.inventory.currency-=15; session.inventory.seals+=3
		show_camp()))
	body.add_child(UIStyle.button(tr("camp.potions"),func():
		if session.inventory.currency>=12: session.inventory.currency-=12; session.inventory.potions+=2
		show_camp()))
	for index in session.inventory.items.size():
		body.add_child(UIStyle.button(tr("camp.stash")%tr(Database.items[session.inventory.items[index].base].name_key),func(): session.inventory.transfer(index,session.stash); show_camp()))
	for index in session.stash.items.size():
		body.add_child(UIStyle.button(tr("camp.take")%tr(Database.items[session.stash.items[index].base].name_key),func(): session.stash.transfer(index,session.inventory); show_camp()))
	body.add_child(UIStyle.button(tr("camp.expedition"),session.new_expedition))

func show_defeat() -> void:
	var trainer: Actor = session.world.trainer
	var animation := trainer.presentation.character_animation
	get_tree().paused = true
	Audio.duck(true)
	if animation != null and not animation.defeat_complete:
		if pending_defeat != null and pending_defeat.get_ref()==trainer: return
		panel.hide()
		shade.hide()
		pending_defeat = weakref(trainer)
		trainer.presentation.defeat_finished.connect(finish_defeat.bind(pending_defeat),CONNECT_ONE_SHOT)
		return
	pending_defeat = null
	var body := open_panel(tr("defeat.title"),tr("defeat.hint"),show_defeat)
	body.add_child(UIStyle.button(tr("defeat.return"),session.revive))

func finish_defeat(expected: WeakRef) -> void:
	var trainer = expected.get_ref()
	if pending_defeat!=expected or not is_instance_valid(trainer): return
	if not is_instance_valid(session.world) or session.world.trainer!=trainer or trainer.health.current>0: return
	show_defeat()

func show_debug() -> void:
	var body := open_panel(tr("debug.title"),tr("debug.stats") % [session.seed_value,session.combat_damage/maxf(1,session.world.elapsed),session.combat_events],show_debug)
	var console := LineEdit.new()
	console.placeholder_text = "god / spawn cinder / item prism / level 5 / status burn / teleport 2000 900"
	body.add_child(console)
	var output := UIStyle.label(tr("debug.help"),12,UIStyle.MUTED)
	output.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(output)
	debug_console = DeveloperConsole.new()
	debug_console.session = session
	console.text_submitted.connect(func(command): output.text = debug_console.execute(command); console.clear())
	body.add_child(UIStyle.button(tr("debug.collision"),func(): session.world.debug_draw = not session.world.debug_draw))
	body.add_child(UIStyle.button(tr("debug.seed"),func(): DisplayServer.clipboard_set(str(session.seed_value))))
	body.add_child(UIStyle.button(tr("debug.stress"),func(): debug_console.execute("stress 30"); close_panel()))

func fade(out: bool) -> void:
	var tween := create_tween()
	tween.tween_property(fade_rect,"modulate:a",1.0 if out else 0.0,.22)
	await tween.finished
