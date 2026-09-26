extends RefCounted

func run(session, check: Callable) -> void:
	var world: GameWorld = session.world
	world.set_physics_process(false)
	for entry in world.actors: entry.set_physics_process(false)
	var trainer_position := world.trainer.position
	for id in ["cinder","rill","briar","volt","solstice"]:
		var actor := world.spawn_actor("species."+id,Factions.Team.WILD,Vector2(700,650))
		actor.set_physics_process(false)
		var animation := actor.presentation.creature_animation
		var definition := animation.definition
		check.call(definition.frames.size()==18 and definition.action_frames.size()>=18 and definition.directions.has_all(["east","south","north"]),id+" has separate front/back walk and combat art")
		for direction in [Vector2.DOWN,Vector2.UP]:
			var facing := "south" if direction.y>0 else "north"
			var offset := 6 if direction.y>0 else 12
			actor.combat.rest()
			actor.abilities.interrupt()
			actor.presentation.recover()
			actor.last_direction = direction
			actor.velocity = direction*90
			var seen := {}
			for step in 100:
				actor.position += direction*1.5
				animation.tick(1.0/60)
				seen[animation.current_frame] = true
			check.call(seen.size()==6 and seen.keys().all(func(frame): return frame in range(offset,offset+6)),id+" cycles six actual walking frames facing "+facing)
			actor.velocity = Vector2.ZERO
			var distance := animation.distance
			animation.tick(.1)
			check.call(animation.facing==facing and animation.distance==distance and not animation.sprite.flip_h,id+" stops in the correct direction without advancing feet: "+facing)
			world.trainer.position = actor.position+direction*100
			actor.last_direction = Vector2.RIGHT
			actor.abilities.cast(actor.ability_id(0),world.trainer)
			animation.tick(0)
			check.call(animation.facing==facing and animation.current_frame==offset and animation.sprite.texture.atlas==definition.texture_for(definition.action_frames[offset],true),id+" planted windup faces its target using directional art: "+facing)
			actor.abilities.tick(actor.abilities.current.windup+.001)
			animation.tick(0)
			check.call(animation.current_clip=="release" and animation.current_frame==offset+2,id+" activation selects directional release: "+facing)
			actor.abilities.interrupt()
			animation.tick(0)
			check.call(animation.facing==facing,id+" keeps final attack facing on return to idle: "+facing)
			animation.tick(0,true)
			check.call(animation.current_frame==offset+4,id+" hit reaction uses correct direction: "+facing)
			actor.health.damage(1000000)
			animation.tick(definition.death_duration+.1)
			var frame: Dictionary = definition.action_frames[animation.current_frame]
			var ground: float = animation.sprite.position.y+(frame.anchor[1]-frame.region[3]*.5)*definition.scale_for(frame,true)
			var final_frame: int = definition.clips[definition.clip_id("death",facing)][-1]
			check.call(animation.current_frame==final_frame and absf(ground)<=.5 and animation.sprite.rotation==0,id+" directional defeat stays grounded after cast interruption: "+facing)
		actor.combat.rest()
		actor.presentation.recover()
		actor.abilities.interrupt()
		actor.abilities.cooldowns.reset()
		world.trainer.position = actor.position+Vector2(0,100)
		actor.abilities.cast(actor.ability_id(0),world.trainer)
		actor.velocity = Vector2(0,-90)
		actor.last_direction = Vector2.UP
		actor.position += Vector2(0,-2)
		animation.tick(1.0/60)
		check.call(animation.current_clip=="walk" and animation.current_frame in range(12,18),id+" keeps northbound stepping during a southward cast")
		world.remove_actor(actor)
	world.trainer.position = trainer_position
