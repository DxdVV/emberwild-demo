extends RefCounted

func run(session, check: Callable) -> void:
	for id in ["species.cinder","species.rill","species.briar","species.volt","species.solstice"]:
		var actor: Actor = session.world.spawn_actor(id,Factions.Team.COMPANION,Vector2(600,600))
		actor.set_physics_process(false)
		var animation := actor.presentation.creature_animation
		var definition := animation.definition
		for direction in [Vector2.RIGHT,Vector2.DOWN,Vector2.UP,Vector2.LEFT]:
			actor.combat.rest()
			actor.presentation.recover()
			actor.last_direction = direction
			actor.presentation.tick(0)
			var origin := actor.position
			var currency: int = session.inventory.currency
			actor.health.damage(1000000)
			var state: Dictionary = actor.combat.to_dict()
			var seen := {}
			var grounded := true
			var lowest := -INF
			var first_height := 0.0
			for step in 50:
				seen[animation.current_frame] = true
				var data: Dictionary = definition.action_frames[animation.current_frame]
				var foot_height: float = animation.sprite.position.y+(data.anchor[1]-data.region[3]*.5)*definition.scale_for(data,true)
				if step==0: first_height = foot_height
				if definition.autoplay and step<12:
					grounded = grounded and foot_height>=lowest-1 and foot_height<=.5
					lowest = foot_height
				else: grounded = grounded and absf(foot_height)<=.5
				actor.presentation.tick(1.0/60)
				if step==12:
					var elapsed := animation.dead_time
					actor.presentation.fall()
					check.call(animation.dead_time==elapsed,id+" repeated visual fall does not restart: "+str(direction))
			var clip: Array = definition.clips[definition.clip_id("death",animation.facing)]
			check.call(clip.size()==6 and seen.size()==6 and seen.keys().all(func(index): return index in clip),id+" plays six distinct authored collapse poses: "+str(direction))
			check.call(grounded and actor.position==origin and animation.sprite.rotation==0 and animation.sprite.flip_h==(direction==Vector2.LEFT),id+" collapse keeps ground contact and facing: "+str(direction))
			if definition.autoplay: check.call(absf(first_height+16)<=.5,id+" airborne fall starts at its flight height and reaches ground by the third pose: "+str(direction))
			check.call(actor.combat.to_dict()==state and session.inventory.currency==currency and actor.abilities.phase==AbilityController.Phase.IDLE,id+" visual collapse cannot advance combat or award loot: "+str(direction))
			var last_texture := animation.sprite.texture
			actor.presentation.tick(1000)
			check.call(animation.dead_time==definition.death_duration and animation.sprite.texture==last_texture and animation.current_frame==clip[-1],id+" final resting pose is retained without accumulating time: "+str(direction))
			actor.combat.rest()
			actor.presentation.recover()
			check.call(not animation.defeated and animation.dead_time==0 and animation.current_clip==("walk" if definition.autoplay else "idle"),id+" revival clears collapse state: "+str(direction))
		session.world.remove_actor(actor)
