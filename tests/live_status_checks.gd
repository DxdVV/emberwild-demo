extends RefCounted

func run(session, check: Callable) -> void:
	session.hud.close_panel(true)
	session.new_journey()
	session.change_area("area.haven",false)
	session.world.set_physics_process(false)
	for actor in session.world.actors: actor.set_physics_process(false)
	var source: Actor = session.world.spawn_actor("species.briar",Factions.Team.WILD,session.world.trainer.position+Vector2(140,0))
	source.set_physics_process(false)
	var state: CombatState = session.world.trainer.combat
	state.health.invulnerable = 100
	for id in ["status.burn","status.burn","status.slow"]: state.statuses.apply(id,source)
	state.health.shield = 22
	session.hud.refresh_status_strips()
	var strip: StatusStrip = session.hud.status_strips[0]
	check.call(strip.visible and strip.badges.size()==3 and strip.badges[1].stacks==2,"live HUD shows trainer shield and stacked statuses")
	check.call(not session.hud.status_strips[1].visible and not session.hud.status_strips[2].visible,"unaffected companions do not create empty effect panels")
	var snapshot := state.to_dict()
	var rng_before: int = session.world.damage.rng.state
	var hover: StatusHover = strip._make_custom_tooltip("status.burn")
	session.hud.root.add_child(hover)
	hover.refresh()
	for index in 10: session.hud.refresh_status_strips()
	check.call(snapshot==state.to_dict() and rng_before==session.world.damage.rng.state,"live badges and hover descriptions never advance combat or RNG")
	var old_description := hover.description.text
	state.statuses.tick(.55)
	session.hud.refresh_status_strips()
	hover.refresh()
	check.call(strip.badges[1].value=="3.5" and hover.description.text!=old_description,"visible effect countdown and open tooltip follow actual remaining time")
	state.statuses.tick(3.45)
	session.hud.refresh_status_strips()
	hover.refresh()
	check.call(strip.badges.size()==1 and hover.description.text.begins_with(TooltipPresenter.t("hud.effect_expired")),"expired statuses disappear and an open tooltip does not retain old damage")
	state.health.damage(5) # Invulnerability preserves the shield.
	state.health.invulnerable = 0
	state.health.damage(22)
	session.hud.refresh_status_strips()
	check.call(not strip.visible,"consumed shield removes its badge immediately on HUD refresh")
	for id in Database.statuses: state.statuses.apply(id,source)
	state.health.shield = 30
	session.hud.refresh_status_strips()
	check.call(strip.badges.size()==8 and strip.badges.size()*StatusStrip.BADGE_WIDTH<=strip.size.x,"all current effects plus shield fit without hiding effects")
	var glyphs: Dictionary = {}
	for definition: StatusData in Database.statuses.values(): glyphs[str(definition.icon_rows)] = true
	check.call(glyphs.size()==Database.statuses.size(),"all seven effects are distinguishable by shape, not color alone")
	var original_icon: Array[String] = Database.statuses["status.wet"].icon_rows
	var invalid_icon: Array[String] = ["invalid"]
	Database.statuses["status.wet"].icon_rows = invalid_icon
	check.call(not ContentValidator.validate(Database).is_empty(),"content validation rejects a malformed status glyph")
	Database.statuses["status.wet"].icon_rows = original_icon
	var companion: CombatState = session.party.roster[0].ensure_combat()
	companion.statuses.apply("status.poison",source)
	session.hud.refresh_status_strips()
	check.call(session.hud.status_strips[1].visible,"active companion effects use its persistent combat state")
	session.party.swap_remaining = 0
	session.party.swap(2,0)
	session.hud.refresh_status_strips()
	check.call(not session.hud.status_strips[1].visible and session.hud.status_strips[1].state_ref.get_ref()==session.party.roster[2].ensure_combat(),"swapping companions replaces the effect owner without stale badges")
	session.world.focus_target = source
	source.statuses.apply("status.wet",session.world.trainer)
	session.hud.refresh_status_strips()
	check.call(session.hud.focus_status.visible and session.hud.focus_status.badges.size()==1,"focused enemy exposes its own health and effects")
	source.position += Vector2(700,0)
	session.hud.refresh_status_strips()
	check.call(not session.hud.focus_status.visible,"distant focused enemies do not leave a misleading live panel")
	source.position -= Vector2(700,0)
	session.world.remove_actor(source)
	await session.get_tree().process_frame
	session.hud.refresh_status_strips()
	check.call(not session.hud.focus_status.visible,"despawned focus targets safely clear their effect panel")
	session.hud.status_strips[0].inspect_requested.emit()
	check.call(session.get_tree().paused and session.hud.status_strips.all(func(value): return not value.visible),"effect inspection pauses combat and hides live overlays beneath the menu")
	session.hud.close_panel(true)
	hover.queue_free()
	session.new_journey()
	session.change_area("area.haven",false)
	session.hud.refresh_status_strips()
	check.call(session.hud.status_strips.all(func(value): return not value.visible),"world replacement does not retain previous trainer or companion effects")
