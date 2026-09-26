extends RefCounted

func settle(tree: SceneTree) -> void:
	for index in 5: await tree.process_frame

func reveal(tooltip: ContextTooltip, control: Control) -> void:
	control.grab_focus()
	tooltip.keyboard = true
	tooltip._process(.5)
	tooltip._process(.5)
	await settle(tooltip.get_tree())

func run(session, check: Callable) -> void:
	var hud: GameHUD = session.hud
	var tooltip := hud.context_tooltip
	var tree: SceneTree = session.get_tree()
	hud.close_panel(true)
	tree.paused = true
	var state: CombatState = session.party.active_actors[0].combat
	var snapshot := state.to_dict()
	var rng_before: int = session.world.damage.rng.state
	await reveal(tooltip,hud.skill_labels[0])
	check.call(tooltip.visible and tooltip.description.text==hud.skill_tooltip(0),"keyboard focus opens actual companion ability description")
	check.call(snapshot==state.to_dict() and rng_before==session.world.damage.rng.state,"contextual descriptions preserve combat and seeded RNG")
	var before := tooltip.description.text
	state.stats.set_source("tooltip-check",[{"stat":"attack","op":"flat","value":37}])
	tooltip._process(.2)
	check.call(tooltip.description.text!=before and tooltip.description.text==hud.skill_tooltip(0),"open ability tooltip tracks current stat modifiers")
	state.stats.remove_source("tooltip-check")
	var actors: Array = session.party.active_actors.duplicate()
	session.party.active_actors.clear()
	tooltip._process(.2)
	check.call(not tooltip.visible,"missing companion clears an already open ability tooltip")
	session.party.active_actors.assign(actors)
	tooltip._process(.2)
	check.call(tooltip.visible,"restored companion repopulates tooltip without another mouse enter")
	hud.show_party()
	check.call(not tooltip.visible,"opening a modal clears the gameplay tooltip immediately")
	await settle(tree)
	var portrait: Control
	for control in hud.modal_focus.controls():
		if control is TextureRect: portrait = control; break
	await reveal(tooltip,portrait)
	check.call(tooltip.visible and tooltip.description.text==TooltipPresenter.creature_text(session.party.roster[0]),"party portrait exposes live creature details by keyboard")
	check.call(Rect2(Vector2.ZERO,hud.root.size).encloses(tooltip.get_global_rect()),"creature description fits the UI viewport")
	var old_locale: String = Settings.locale
	Settings.set_locale("en" if old_locale=="ru" else "ru",false)
	await settle(tree)
	check.call(not tooltip.visible and not is_instance_valid(portrait),"language rebuild discards the old focused tooltip and owner")
	Settings.set_locale(old_locale,false)
	hud.close_panel(true)
	tree.paused = true
	var corner := Button.new()
	corner.text = "test"
	corner.size = Vector2(65,32)
	hud.root.add_child(corner)
	ContextTooltip.bind(corner,func(): return TooltipPresenter.creature_text(session.party.roster[0]))
	for at in [Vector2(8,8),Vector2(887,8),Vector2(8,500),Vector2(887,500)]:
		corner.position = at
		await reveal(tooltip,corner)
		tooltip.place()
		check.call(Rect2(Vector2(8,8),hud.root.size-Vector2(16,16)).encloses(tooltip.get_global_rect()),"context tooltip remains inside viewport at corner "+str(at))
	corner.set_meta(ContextTooltip.IDENTITY,"replacement")
	tooltip._process(.2)
	check.call(not tooltip.visible,"reusing a hit target for another item restarts tooltip delay")
	tooltip._process(.5)
	check.call(tooltip.visible,"reused hit target displays the new identity after the delay")
	corner.queue_free()
	await settle(tree)
	tooltip._process(.2)
	check.call(not tooltip.visible,"freed tooltip owner cannot leave a stale floating description")
	hud.show_inventory()
	await settle(tree)
	var target: OptionButton
	for control in hud.modal_focus.controls():
		if control is OptionButton: target = control; break
	ContextTooltip.bind(target,func(): return "test")
	await reveal(tooltip,target)
	target.show_popup()
	tooltip._process(.2)
	check.call(not tooltip.visible,"open option popup suppresses contextual overlay")
	target.get_popup().hide()
	hud.close_panel(true)
	await settle(tree)
