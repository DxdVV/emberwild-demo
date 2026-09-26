class_name AbilityResolver extends RefCounted

# Every delivery uses the same per-victim reactions and damage pipeline.
static func resolve(world: GameWorld, source: Actor, targets: Array, ability: AbilityData, context: Dictionary) -> void:
	var hit: Array = []
	var chain_count: int = int(context.get("chains",0))
	var origin := source.global_position
	for target in targets:
		if not TargetingSystem.valid(source,target) or target in hit: continue
		hit.append(target)
		origin = target.global_position
		var local_context := context.duplicate()
		if target.health.invulnerable<=0:
			for reaction in Database.rules.reactions:
				if not target.statuses.entries.has(reaction.status) or str(ability.element)!=reaction.element: continue
				match reaction.effect:
					"chain": chain_count += int(reaction.count)
					"bonus": local_context["base_damage"] = source.stats.value("attack")*ability.power*float(reaction.multiplier)
				target.statuses.remove(reaction.status)
				world.effects.floating(target.global_position,TranslationServer.translate("combat.reaction"),Color("fff2a0"))
		world.damage.apply(source,target,ability,local_context)
		world.effects.burst(target.global_position,ability.color,8)
	for jump in mini(4,chain_count):
		var next = TargetingSystem.nearest(source,world.actors,origin,170,hit)
		if next==null: break
		hit.append(next)
		# Secondary jumps cannot recursively create triggers or new chains.
		world.damage.apply(source,next,ability,{"depth":TriggerComponent.MAX_DEPTH})
		world.effects.burst(next.global_position,ability.color,8)
		origin = next.global_position
