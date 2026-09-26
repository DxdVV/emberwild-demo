extends RefCounted

func run(session, check: Callable) -> void:
	session.world.set_physics_process(false)
	for entry in session.world.actors: entry.set_physics_process(false)
	for id in Database.species:
		var actor: Actor = session.world.spawn_actor(id,Factions.Team.WILD,session.world.trainer.position+Vector2(80,0))
		actor.set_physics_process(false)
		var animation := actor.presentation.creature_animation
		check.call(animation!=null and animation.definition.clips.has("death"),id+" has authored combat/death animation")
		if animation==null: continue
		var ability: AbilityData = Database.abilities[actor.species.abilities[0]]
		check.call(actor.abilities.cast(str(ability.id),session.world.trainer),id+" starts real ability windup")
		actor.presentation.tick(0)
		var anticipation := animation.current_frame
		actor.abilities.tick(ability.windup*.7)
		actor.presentation.tick(0)
		check.call(animation.current_clip=="windup" and animation.current_frame!=anticipation,id+" advances anticipation frames with ability phase")
		actor.abilities.tick(ability.windup*.31)
		actor.presentation.tick(0)
		check.call(animation.current_clip=="release" and animation.current_frame==2,id+" release frame follows gameplay activation")
		actor.abilities.interrupt()
		actor.presentation.hit()
		actor.presentation.tick(.01)
		check.call(animation.current_clip=="hurt" and animation.current_frame==4,id+" uses distinct hit reaction")
		actor.health.damage(1000000)
		actor.presentation.tick(animation.definition.death_duration+.1)
		var frame: Dictionary = animation.definition.action_frames[animation.current_frame]
		var ground_y: float = actor.presentation.sprite.position.y+(frame.anchor[1]-frame.region[3]*.5)*animation.definition.scale_for(frame,true)
		var final_frame: int = animation.definition.clips[animation.definition.clip_id("death",animation.facing)][-1]
		check.call(animation.current_clip=="death" and animation.current_frame==final_frame and absf(ground_y)<=.5 and actor.presentation.sprite.rotation==0,id+" ends in grounded prone frame without rotating a standing sprite")
		actor.combat.rest()
		actor.presentation.recover()
		check.call(animation.dead_time==0 and animation.current_clip!="death" and actor.presentation.sprite.modulate.a==1,id+" revival resets animation state")
		session.world.remove_actor(actor)
	var boss: Actor = session.world.spawn_actor("species.guardian",Factions.Team.BOSS,session.world.trainer.position+Vector2(160,0))
	boss.set_physics_process(false)
	for direction in [Vector2.RIGHT,Vector2.DOWN,Vector2.UP]:
		boss.last_direction = direction
		boss.velocity = direction*75
		boss.position += direction*2
		boss.presentation.tick(1.0/30)
		var expected := 0 if direction==Vector2.RIGHT else (6 if direction==Vector2.DOWN else 12)
		check.call(boss.presentation.creature_animation.current_frame in range(expected,expected+6),"guardian selects directional walking row "+str(direction))
	boss.brain.boss_time = 0
	boss.brain.tick(1.0/60)
	boss.presentation.tick(0)
	check.call(boss.brain.special_remaining>0 and boss.velocity==Vector2.ZERO and boss.presentation.creature_animation.current_clip=="windup","boss telegraph plants feet and starts slam anticipation")
	var hazards: Array = session.world.get_children().filter(func(node): return node is GroundHazard)
	check.call(not hazards.is_empty() and is_equal_approx(hazards[-1].duration,boss.brain.special_windup),"slam animation windup shares ground-warning timing")
	boss.brain.special_remaining = boss.brain.special_recovery
	boss.presentation.tick(0)
	check.call(boss.presentation.creature_animation.current_clip=="release" and boss.presentation.creature_animation.current_frame==2,"boss ground impact selects planted-fists pose")
	boss.health.damage(1000000)
	for hazard in hazards:
		hazard._physics_process(.01)
	check.call(hazards.all(func(hazard): return hazard.is_queued_for_deletion()),"defeated boss cancels outstanding ground warnings")
	session.world.remove_actor(boss)
