class_name PartySystem extends RefCounted

signal changed
signal creature_about_to_swap_out(id: String)
signal creature_swapped_out(id: String)
signal creature_swapped_in(id: String)
var world
var roster: Array[CreatureInstance] = []
var active_indices: Array[int] = [0,1]
var active_actors: Array = []
var swap_remaining: float = 0
var mode: ActorBrain.Mode = ActorBrain.Mode.AGGRESSIVE

func add(creature: CreatureInstance) -> bool:
	if roster.size() >= Database.rules.party_limit: return false
	if roster.any(func(entry): return entry.persistent_id==creature.persistent_id): return false
	roster.append(creature)
	changed.emit()
	return true

func evolve(index: int) -> bool:
	if index<0 or index>=roster.size(): return false
	var creature := roster[index]
	if not Progression.evolve(creature): return false
	for actor in active_actors:
		if is_instance_valid(actor) and actor.individual==creature:
			actor.species = Database.species[creature.species_id]
			actor.presentation.refresh_species()
	changed.emit()
	return true

func placements() -> Dictionary:
	var result: Dictionary = {}
	for actor in active_actors:
		if is_instance_valid(actor):
			result[actor.identity] = {"position":[actor.position.x,actor.position.y],"direction":[actor.last_direction.x,actor.last_direction.y]}
	return result

func summon(saved_placements: Dictionary = {}, restoring: bool = false) -> void:
	active_actors.clear()
	for creature in roster: creature.ensure_combat().damage_system = world.damage
	for slot in active_indices.size():
		var index: int = active_indices[slot]
		if index < 0 or index >= roster.size(): continue
		var individual := roster[index]
		var placement: Dictionary = saved_placements.get(individual.persistent_id,{})
		var at: Vector2 = world.arrival_position(placement,summon_position(Vector2(-60+slot*110,40)))
		var direction := AreaLayout.point(placement.get("direction",[1,0]))
		var actor = world.spawn_actor(individual.species_id,Factions.Team.COMPANION,at,individual,{},direction)
		actor.brain.mode = mode
		active_actors.append(actor)
		# Reconstructing a save is not a new gameplay summon or swap.
		if not restoring:
			actor.triggers.fire("summon")
			creature_swapped_in.emit(individual.persistent_id)
	changed.emit()

func swap(index: int, slot: int = 0) -> bool:
	if swap_remaining > 0 or index < 0 or index>=roster.size() or roster[index].health_ratio<=0 or index in active_indices: return false
	if slot<0 or slot>=active_indices.size(): return false
	if slot<active_actors.size() and is_instance_valid(active_actors[slot]):
		var old = active_actors[slot]
		creature_about_to_swap_out.emit(old.identity)
		old.individual.health_ratio = old.health.current/old.health.maximum
		world.remove_actor(old)
		creature_swapped_out.emit(old.identity)
	active_indices[slot] = index
	var actor = world.spawn_actor(roster[index].species_id,Factions.Team.COMPANION,summon_position(Vector2(35,25)),roster[index])
	actor.health.invulnerable = .6
	actor.brain.mode = mode
	actor.triggers.fire("swap")
	if slot<active_actors.size(): active_actors[slot] = actor
	else: active_actors.append(actor)
	creature_swapped_in.emit(actor.identity)
	swap_remaining = Database.rules.swap_cooldown
	world.effects.burst(actor.global_position,actor.species.color,20)
	Audio.play("capture",actor.global_position)
	changed.emit()
	return true

func summon_position(offset: Vector2) -> Vector2:
	var at: Vector2 = world.navigation.safe_position_near(world.trainer.global_position+offset)
	return world.trainer.global_position if at==Vector2.INF else at

func cycle_mode() -> void:
	mode = ((int(mode)+1)%4) as ActorBrain.Mode
	for actor in active_actors:
		if is_instance_valid(actor): actor.brain.mode = mode
	changed.emit()

func rest() -> void:
	for creature in roster:
		creature.ensure_combat().rest()
		creature.sync_health()
	changed.emit()

func tick(delta: float) -> void:
	swap_remaining = maxf(0,swap_remaining-delta)
	for index in roster.size():
		if index in active_indices: continue
		var creature := roster[index]
		var state := creature.ensure_combat()
		var was_alive := state.health.current>0
		state.tick(delta)
		creature.sync_health()
		if was_alive and state.health.current<=0:
			world.notice(tr("notice.reserve_defeated")%tr(Database.species[creature.species_id].name_key))
			changed.emit()
