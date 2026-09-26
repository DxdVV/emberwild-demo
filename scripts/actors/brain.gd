class_name ActorBrain extends RefCounted

enum State {IDLE, FOLLOW, CHASE, ATTACK, RETURN, HOLD, DEAD, EVADE}
enum Mode {AGGRESSIVE, DEFENSIVE, FOLLOW, HOLD, FOCUS}
var actor
var state: State = State.IDLE
var mode: Mode = Mode.AGGRESSIVE
var target_ref: WeakRef
var perception_remaining: float = 0
var stuck_time: float = 0
var previous_position: Vector2
var boss_time: float = 2
var boss_phase: int = 0
var special_remaining: float = 0
var special_windup: float = 1.1
var special_recovery: float = .28
var special_direction := Vector2.RIGHT
var hold_position: Vector2
var route := PackedVector2Array()
var route_goal := Vector2.INF
var route_revision: int = -1
var route_remaining: float = 0
var recovery_remaining: float = 0
var wants_to_move: bool = false
var recovery_count: int = 0
var escape_goal := Vector2.INF
var escape_retry_remaining: float = 0

func transition(next: State) -> void:
	if state == next: return
	state = next
	if next == State.HOLD: hold_position = actor.global_position

func tick(delta: float) -> void:
	escape_retry_remaining = maxf(0,escape_retry_remaining-delta)
	route_remaining = maxf(0,route_remaining-delta)
	recovery_remaining = maxf(0,recovery_remaining-delta)
	wants_to_move = false
	special_remaining = maxf(0,special_remaining-delta)
	if actor.health.current <= 0:
		transition(State.DEAD)
		return
	perception_remaining -= delta
	var companion: bool = actor.faction == Factions.Team.COMPANION
	var trainer = actor.world.trainer
	if companion and mode!=Mode.HOLD and actor.global_position.distance_to(trainer.global_position)>650:
		recover_near_trainer()
	if companion and mode == Mode.HOLD:
		transition(State.HOLD)
	if companion and mode == Mode.FOLLOW:
		target_ref = null
	elif perception_remaining <= 0:
		perception_remaining = .22
		var reach := 380.0 if companion else 320.0
		if companion and mode == Mode.DEFENSIVE: reach = 180
		var target = actor.world.focus_target if companion and TargetingSystem.valid(actor,actor.world.focus_target) else TargetingSystem.nearest(actor,actor.world.actors,actor.global_position,reach)
		target_ref = weakref(target) if target != null else null
	var target = target_ref.get_ref() if target_ref != null else null
	actor.velocity = Vector2.ZERO
	if companion and mode!=Mode.HOLD and evade_hazards(delta): return
	if mode==Mode.HOLD: escape_goal = Vector2.INF
	if actor.faction == Factions.Team.BOSS:
		if TargetingSystem.valid(actor,target): boss_tick(delta,target)
		# A telegraphed strike stays planted and faces its committed ground marker,
		# even if the target moves away or disappears during the windup.
		if special_remaining>0:
			transition(State.ATTACK)
			actor.last_direction = special_direction
			return
	if TargetingSystem.valid(actor,target):
		var basic: AbilityData = Database.abilities[actor.ability_id(0)]
		var distance: float = actor.global_position.distance_to(target.global_position)
		if distance > basic.reach*.85:
			transition(State.CHASE)
			if mode != Mode.HOLD: steer(target.global_position,delta)
		else:
			transition(State.ATTACK)
			actor.abilities.cast(str(basic.id),target)
			if mode!=Mode.HOLD and actor.species.ai_profile == &"ranged" and distance < 85: steer(actor.global_position+(actor.global_position-target.global_position).normalized()*50,delta)
	elif companion:
		var offset := follow_offset()
		if mode == Mode.HOLD: return
		transition(State.FOLLOW)
		if actor.global_position.distance_to(trainer.global_position+offset)>40: steer(trainer.global_position+offset,delta)
	else:
		transition(State.RETURN)
		if actor.global_position.distance_to(actor.spawn_origin)>35: steer(actor.spawn_origin,delta)
	if wants_to_move and actor.global_position.distance_to(previous_position)<.3: stuck_time += delta
	else: stuck_time = 0
	# The bounded repath interval already retries blocked routes. Do not reset it every
	# stuck frame: an unreachable endpoint would otherwise trigger AStar at 60 Hz.
	if companion and mode!=Mode.HOLD and stuck_time>2 and (actor.global_position.distance_to(trainer.global_position)>150 or not actor.world.navigation.point_clear(actor.global_position,actor.body_radius)):
		recover_near_trainer()
	previous_position = actor.global_position

func evade_hazards(delta: float) -> bool:
	var threats: Array[GroundHazard] = []
	var inside := false
	for hazard: GroundHazard in actor.world.hazards:
		if hazard.activated or hazard.is_queued_for_deletion(): continue
		var source = hazard.source_ref.get_ref()
		if not is_instance_valid(source) or source.is_queued_for_deletion() or source.health.current<=0: continue
		if not TargetingSystem.valid(source,actor): continue
		# Distant telegraphs cannot keep a companion in an old evasive state.
		if actor.global_position.distance_to(hazard.global_position)>hazard.radius+190: continue
		threats.append(hazard)
		if actor.global_position.distance_to(hazard.global_position)<hazard.radius+actor.body_radius+6: inside = true
	if threats.is_empty() or (not inside and escape_goal==Vector2.INF):
		escape_goal = Vector2.INF
		escape_retry_remaining = 0
		return false
	var navigation: WorldNavigation = actor.world.navigation
	if escape_goal==Vector2.INF and escape_retry_remaining>0: return false
	if escape_goal==Vector2.INF or not navigation.point_clear(escape_goal,actor.body_radius) or not safe_from_hazards(escape_goal,threats):
		escape_goal = Vector2.INF
		escape_retry_remaining = .2
		var best := INF
		# Bounded candidate search, then the existing cached AStar steering.
		for hazard in threats:
			for scale in [1.0,1.4]:
				for index in 16:
					var candidate: Vector2 = hazard.global_position+Vector2.from_angle(index*TAU/16)*(hazard.radius+actor.body_radius+12)*scale
					var distance: float = actor.global_position.distance_squared_to(candidate)
					if distance>=best or not navigation.point_clear(candidate,actor.body_radius) or not safe_from_hazards(candidate,threats): continue
					if not navigation.segment_clear(actor.global_position,candidate,actor.body_radius): continue
					escape_goal = candidate
					best = distance
	if escape_goal==Vector2.INF: return false
	transition(State.EVADE)
	if actor.global_position.distance_to(escape_goal)>4: steer(escape_goal,delta)
	previous_position = actor.global_position
	return true

func safe_from_hazards(at: Vector2, threats: Array[GroundHazard]) -> bool:
	for hazard in threats:
		if at.distance_to(hazard.global_position)<hazard.radius+actor.body_radius+8: return false
	return true

func steer(destination: Vector2, delta: float) -> void:
	wants_to_move = true
	var navigation: WorldNavigation = actor.world.navigation
	if route_remaining<=0 or route_revision!=navigation.revision or route_goal.distance_squared_to(destination)>24*24:
		route = navigation.path(actor.global_position,destination,actor.body_radius)
		route_goal = destination
		route_revision = navigation.revision
		var stagger := posmod(int(actor.spawn_origin.x)*31+int(actor.spawn_origin.y)*17+actor.faction,7)
		route_remaining = .35+float(stagger)*.015
	while not route.is_empty() and actor.global_position.distance_squared_to(route[0])<.25: route.remove_at(0)
	if route.is_empty():
		actor.velocity = Vector2.ZERO
		return
	var distance: float = actor.global_position.distance_to(route[0])
	actor.velocity = actor.global_position.direction_to(route[0])*minf(actor.stats.value("speed"),distance/maxf(.001,delta))

func follow_offset() -> Vector2:
	var slot: int = actor.world.session.party.active_actors.find(actor)
	return Vector2(50,45) if slot==1 else Vector2(-65,35)

func recover_near_trainer() -> bool:
	if recovery_remaining>0: return false
	recovery_remaining = 3
	var at: Vector2 = actor.world.navigation.safe_position_near(actor.world.trainer.global_position+Vector2(-45,35),actor.body_radius)
	if at==Vector2.INF: return false
	actor.global_position = at
	actor.velocity = Vector2.ZERO
	actor.external_velocity = Vector2.ZERO
	previous_position = at
	route.clear()
	route_remaining = 0
	stuck_time = 0
	recovery_count += 1
	actor.world.effects.burst(at,Color("8de5c4"),10)
	return true

func boss_tick(delta: float, target) -> void:
	var phases: Array = Database.rules.boss_phases
	var ratio: float = actor.health.current/actor.health.maximum
	var selected := 0
	for index in phases.size():
		if ratio <= float(phases[index].threshold): selected = index
	if selected != boss_phase:
		boss_phase = selected
		actor.world.notice(tr("notice.phase")%(boss_phase+1))
		actor.world.camera.impulse(6)
		actor.world.spawn_adds(actor.global_position,2)
	boss_time -= delta
	if boss_time <= 0 and special_remaining<=0:
		boss_time = float(phases[boss_phase].interval)
		actor.abilities.interrupt()
		var ability: AbilityData = Database.abilities["ability.slam"]
		special_windup = ability.windup
		special_recovery = ability.recovery+maxi(0,int(phases[boss_phase].waves)-1)*.18
		special_remaining = special_windup+special_recovery
		special_direction = actor.global_position.direction_to(target.global_position)
		if special_direction.is_zero_approx(): special_direction = actor.last_direction
		for wave in int(phases[boss_phase].waves):
			var offset := Vector2.from_angle(wave*TAU/3)*float(wave*55)
			actor.world.hazard(actor,target.global_position+offset,float(phases[boss_phase].radius),special_windup+wave*.18)
