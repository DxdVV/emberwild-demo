extends RefCounted

func run(session, check: Callable) -> void:
	var hud: GameHUD = session.hud
	hud.refresh_party_cards()
	var cards := hud.companion_row.get_children()
	var creature: CreatureInstance = session.party.roster[session.party.active_indices[0]]
	var ratio := creature.health_ratio
	creature.health_ratio = .33
	hud.refresh_party_cards()
	check.call(hud.companion_row.get_children()==cards and "33%" in hud.party_card_details[0].text,"HUD updates health text without recreating companion nodes")
	creature.health_ratio = ratio
	var before: Array = session.party.active_indices.duplicate()
	session.party.active_indices.reverse()
	hud.refresh_party_cards()
	check.call(hud.companion_row.get_children()!=cards and hud.party_card_signature[0].begins_with(session.party.roster[session.party.active_indices[0]].persistent_id),"HUD rebuilds portraits when active slot identity changes")
	session.party.active_indices.assign(before)
	hud.refresh_party_cards()
	var effects := EffectsController.new()
	session.world.add_child(effects)
	check.call(not effects.is_processing(),"empty effect layer has no idle frame work")
	effects.burst(Vector2.ZERO,Color.WHITE,12)
	effects.floating(Vector2.ZERO,"test",Color.WHITE)
	check.call(effects.is_processing() and not effects.particles.is_empty() and effects.rings.size()==1 and effects.labels.size()==1,"burst and floating label wake the effect layer")
	effects._process(.25)
	check.call(not effects.particles.is_empty() and effects.particles[0].at!=Vector2.ZERO,"effect optimization preserves particle movement")
	effects._process(2)
	check.call(effects.particles.is_empty() and effects.rings.is_empty() and effects.labels.is_empty() and not effects.is_processing(),"expired effects clear and stop their processing")
	effects.floating(Vector2.ZERO,"again",Color.WHITE)
	check.call(effects.is_processing() and effects.labels.size()==1,"effect layer can wake again after all effects expire")
	effects.queue_free()
