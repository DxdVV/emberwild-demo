extends RefCounted

func run(session, check: Callable) -> void:
	var world: GameWorld = session.world
	world.set_physics_process(false)
	for value in world.actors: value.set_physics_process(false)
	var actor: Actor = world.trainer
	var animation := actor.presentation.character_animation
	var origin := actor.position
	var target := world.spawn_actor("species.briar",Factions.Team.WILD,origin+Vector2(100,0))
	target.set_physics_process(false)
	target.health.immortal = true
	for direction in [Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT]:
		var row := 0 if direction==Vector2.DOWN else (2 if direction==Vector2.UP else 1)
		actor.combat.rest()
		actor.abilities.interrupt()
		actor.presentation.recover()
		actor.position = origin
		actor.velocity = Vector2.ZERO
		actor.last_direction = Vector2.RIGHT
		animation.previous_position = origin
		target.position = origin+direction*100
		actor.abilities.cast("ability.pulse",target)
		var windup := {}
		var release := {}
		var grounded := true
		var projectile_count := world.get_children().filter(func(node): return node is AbilityProjectile).size()
		for index in 40:
			animation.tick(1.0/60,false)
			if animation.current_clip in ["windup","release"]:
				var frame: Dictionary = animation.definition.action_frames[animation.action_frame]
				grounded = grounded and absf(animation.sprite.position.y+(frame.anchor[1]-frame.region[3]*.5)*animation.definition.scale_for(frame,true))<=.5
				if animation.current_clip=="windup": windup[animation.action_frame] = true
				else: release[animation.action_frame] = true
			actor.abilities.tick(1.0/60)
		check.call(windup.size()==2 and release.size()==2 and windup.keys().all(func(index): return index in range(18+row*6,20+row*6)) and release.keys().all(func(index): return index in range(20+row*6,22+row*6)),"hero uses both anticipation and release frames: "+str(direction))
		check.call(animation.current_clip=="idle" and animation.facing_row==row and animation.sprite.flip_h==(direction==Vector2.LEFT),"planted hero cast faces its target and retains facing on idle: "+str(direction))
		check.call(grounded and animation.sprite.rotation==0 and actor.position==origin,"hero combat frames preserve planted ground contact: "+str(direction))
		check.call(world.get_children().filter(func(node): return node is AbilityProjectile).size()==projectile_count+1,"animation follows one real ability release without additional hits: "+str(direction))
		animation.tick(0,true)
		check.call(animation.current_clip=="hurt" and animation.action_frame==36+row*6,"hero hit reaction retains correct directional art: "+str(direction))
		var state_before := actor.combat.to_dict()
		var hits := {}
		var stable_anchor := true
		for step in 18:
			if animation.current_clip=="hurt":
				hits[animation.action_frame] = true
				var data: Dictionary = animation.definition.action_frames[animation.action_frame]
				stable_anchor = stable_anchor and absf(animation.sprite.position.y+(data.anchor[1]-data.region[3]*.5)*animation.definition.scale_for(data,true))<=.5
			animation.tick(1.0/60,false)
		check.call(hits.size()==3 and hits.keys().all(func(index): return index in range(36+row*6,39+row*6)) and animation.current_clip=="idle","hero recoil plays three distinct poses then returns to idle: "+str(direction))
		check.call(stable_anchor and actor.position==origin and actor.combat.to_dict()==state_before,"hit poses remain grounded and cannot change gameplay state: "+str(direction))
		actor.last_direction = -direction
		actor.dodge_direction = direction
		actor.dodge_time = .2
		var distance := animation.travelled
		actor.position += direction*9
		animation.tick(1.0/60,false)
		check.call(animation.current_clip=="dodge" and animation.action_frame==39+row*6 and animation.travelled==distance,"hero dash follows locked dash direction without stepping: "+str(direction))
		var dashes := {}
		for step in 12:
			actor.dodge_time = Actor.DODGE_DURATION*(1-float(step)/12)
			animation.tick(0,false)
			dashes[animation.action_frame] = true
		check.call(dashes.size()==3 and dashes.keys().all(func(index): return index in range(39+row*6,42+row*6)) and animation.travelled==distance,"dash progress follows its gameplay timer through all three poses: "+str(direction))
		actor.dodge_time = 0
		actor.abilities.interrupt()
		actor.abilities.cooldowns.reset()
		target.position = actor.position-direction*100
		actor.abilities.cast("ability.pulse",target)
		actor.last_direction = direction
		actor.velocity = direction*120
		var seen := {}
		for step in 60:
			actor.position += direction*2
			animation.tick(1.0/60,step%8==0)
			seen[animation.previous_frame] = true
		check.call(seen.size()==6 and seen.keys().all(func(index): return index in range(row*6,row*6+6)),"moving hero keeps six-step gait through casts and hit flashes: "+str(direction))
	actor.abilities.interrupt()
	actor.velocity = Vector2.ZERO
	actor.position = origin
	animation.previous_position = origin
	world.remove_actor(target)
	animation.tick(0,false)
	actor.presentation.hit()
	for step in 10: actor.presentation.tick(1.0/60)
	check.call(actor.presentation.flash==0 and animation.current_clip=="hurt","recoil completes after the short color flash instead of being truncated")
	actor.presentation.hit()
	animation.tick(0,true)
	check.call(animation.hurt_remaining==animation.definition.hurt_duration,"a second actual hit restarts the authored reaction even while it is already playing")
	actor.presentation.recover()
	check.call(animation.hurt_remaining==0 and animation.current_clip=="idle","recovery clears an unfinished hit pose")
