extends RefCounted

func run(session, check: Callable) -> void:
	var world: GameWorld = session.world
	world.set_physics_process(false)
	for actor in world.actors: actor.set_physics_process(false)
	var trainer_at := world.trainer.position
	world.trainer.position = Vector2(1400,1000)
	for case in [[Vector2.DOWN,0],[Vector2.UP,0],[Vector2.RIGHT,0],[Vector2.LEFT,0],[Vector2.DOWN,2],[Vector2.UP,2],[Vector2.RIGHT,2],[Vector2.LEFT,2]]:
		var direction: Vector2 = case[0]
		var phase: int = case[1]
		var boss := world.spawn_actor("species.guardian",Factions.Team.BOSS,Vector2(650,600))
		boss.set_physics_process(false)
		if phase==2: boss.health.current = boss.health.maximum*.25
		boss.brain.boss_phase = phase
		var victim := world.spawn_actor("species.rill",Factions.Team.COMPANION,boss.position+direction*120)
		victim.set_physics_process(false)
		victim.health.maximum = 2000
		victim.health.current = 2000
		var animation := boss.presentation.creature_animation
		boss.brain.target_ref = weakref(victim)
		boss.brain.perception_remaining = 1000
		boss.brain.boss_time = 0
		var old_hazards := world.get_children().filter(func(node): return node is GroundHazard)
		boss.brain.tick(0)
		var hazards := world.get_children().filter(func(node): return node is GroundHazard and node not in old_hazards)
		var waves := 1 if phase==0 else 3
		check.call(hazards.size()==waves,"guardian creates the configured wave count: "+str(case))
		var hazard: GroundHazard = hazards[0]
		for wave: GroundHazard in hazards: wave.set_physics_process(false)
		hazard._physics_process(1.0/60)
		check.call(hazard.elapsed==0,"new guardian telegraph does not consume its creation tick: "+str(direction))
		var marker := hazard.position
		var origin := boss.position
		var facing := "south" if direction==Vector2.DOWN else ("north" if direction==Vector2.UP else "east")
		var seen := {"windup":{},"release":{}}
		var damage_tick := -1
		var matched := true
		var health_before := victim.health.current
		var hits: Array = []
		var boss_id := boss.identity
		var victim_id := victim.identity
		var on_hit := func(request: Dictionary, result: Dictionary):
			if request.source_id==boss_id and request.target_id==victim_id and request.ability=="ability.slam": hits.append({"damage":result.final_damage,"pose":animation.current_clip})
		world.damage.resolved.connect(on_hit)
		for frame in 120:
			if frame==10: victim.position = boss.position-direction*120
			if frame==20: boss.brain.target_ref = null
			if frame==45: victim.position = marker
			boss.brain.tick(1.0/60)
			animation.tick(1.0/60)
			if animation.current_clip in ["windup","release"]:
				seen[animation.current_clip][animation.current_frame] = true
				matched = matched and animation.facing==facing and boss.velocity==Vector2.ZERO and hazard.position==marker
			for wave: GroundHazard in hazards:
				if not wave.is_queued_for_deletion(): wave.advance(1.0/60)
			if damage_tick<0 and hazard.activated:
				damage_tick = frame
				check.call(animation.current_clip=="release" and victim.health.current<health_before,"guardian impact pose coincides with actual area damage: "+str(direction))
		check.call(damage_tick>=0 and absf((damage_tick+1)/60.0-hazard.duration)<.02,"guardian damage waits for the full telegraph: "+str(direction))
		check.call(matched and boss.position==origin and boss.brain.special_direction==direction,"committed guardian slam stays planted and aimed after target movement/loss: "+str(direction))
		check.call(seen.windup.size()==2 and seen.release.size()==2,"guardian telegraph plays both anticipation and impact poses: "+str(direction))
		var damaged_health := victim.health.current
		check.call(damaged_health<health_before and hits.size()==waves and hits.all(func(hit): return hit.pose=="release"),"guardian applies one synchronized hit per committed wave: "+str(case))
		world.damage.resolved.disconnect(on_hit)
		boss.brain.special_remaining = 0
		boss.abilities.interrupt()
		animation.tick(0,true)
		check.call(animation.current_clip=="hurt" and animation.facing==facing,"guardian hurt retains the committed facing: "+str(direction))
		boss.health.damage(100000)
		var death_frames := {}
		var grounded := true
		for frame in 60:
			animation.tick(1.0/60)
			death_frames[animation.current_frame] = true
			var data: Dictionary = animation.definition.action_frames[animation.current_frame]
			grounded = grounded and absf(animation.sprite.position.y+(data.anchor[1]-data.region[3]*.5)*animation.definition.scale_for(data,true))<=.5
		check.call(grounded and animation.facing==facing and animation.sprite.rotation==0 and animation.sprite.flip_h==(direction==Vector2.LEFT),"guardian defeat keeps its ground contact and direction: "+str(direction))
		var expected_atlas: Texture2D = animation.definition.supplemental_textures["side_defeat"] if facing=="east" else animation.definition.directional_texture
		check.call(death_frames.size()==6 and animation.sprite.texture.atlas==expected_atlas,"guardian defeat uses six unique authored frames: "+str(direction))
		world.remove_actor(boss)
		world.remove_actor(victim)
		for wave: GroundHazard in hazards:
			if not wave.is_queued_for_deletion(): wave.queue_free()
	world.trainer.position = trainer_at
