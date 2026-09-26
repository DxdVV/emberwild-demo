extends RefCounted

func run(session, check: Callable) -> void:
	var actor: Actor = session.world.trainer
	actor.set_physics_process(false)
	var animation := actor.presentation.character_animation
	var start := actor.position
	for direction in [Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT]:
		actor.combat.rest()
		actor.presentation.recover()
		actor.velocity = direction*100
		actor.last_direction = direction
		actor.position += direction*2
		animation.tick(1.0/60,false)
		actor.velocity = Vector2.ZERO
		var row := animation.facing_row
		var mirrored := animation.sprite.flip_h
		animation.fall()
		var seen := {}
		var grounded := true
		for step in 70:
			animation.tick(1.0/60,false)
			seen[animation.defeat_frame] = true
			var frame: Dictionary = animation.definition.action_frames[animation.defeat_frame]
			var baseline: float = animation.sprite.position.y+(frame.anchor[1]-frame.region[3]*.5)*animation.definition.action_scale
			grounded = grounded and absf(baseline)<=.5
		check.call(seen.size()==6 and seen.keys().all(func(index): return index in range(row*6,row*6+6)),"hero defeat plays six correct directional frames: "+str(direction))
		check.call(grounded and animation.sprite.rotation==0 and animation.sprite.flip_h==mirrored,"hero falling arc retains ground contact and facing: "+str(direction))
		animation.tick(5,false)
		animation.fall()
		check.call(animation.defeat_frame==row*6+5 and animation.defeat_complete,"hero final defeat pose does not loop or restart: "+str(direction))
		actor.presentation.recover()
		check.call(not animation.defeated and animation.defeat_frame==-1 and animation.sprite.texture.atlas==animation.definition.texture,"explicit recovery restores normal hero frame source: "+str(direction))
	actor.position = start
	# Recovery before presentation finishes must not reopen a stale defeat panel.
	actor.health.invulnerable = 0
	actor.health.immortal = false
	actor.health.damage(100000)
	check.call(session.hud.pending_defeat!=null and session.get_tree().paused,"early recovery fixture enters pending defeat")
	session.revive()
	for index in 70: await session.get_tree().physics_frame
	check.call(not session.get_tree().paused and not session.hud.panel.visible and session.world.trainer.health.current>0,"recovery cancels pending defeat without a late panel or freed-node callback")
