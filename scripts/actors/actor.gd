class_name Actor extends CharacterBody2D

const DODGE_DURATION := .22

signal defeated(actor)
var world
var identity: String = "":
	set(value):
		identity = value
		if combat != null: combat.identity = value
var combat: CombatState
var faction: int = Factions.Team.WILD
var individual: CreatureInstance
var species: SpeciesData
var types: Array = ["neutral"]
var stats := StatsComponent.new()
var health := HealthComponent.new()
var energy := EnergyComponent.new()
var statuses := StatusComponent.new()
var triggers := TriggerComponent.new()
var abilities := AbilityController.new()
var presentation: ActorPresentation
var brain: ActorBrain
var hurtbox: Area2D
var critical_chance: float:
	get: return stats.value("critical_chance")
	set(value): stats.set_source("runtime:critical",[{"stat":"critical_chance","op":"override","value":clampf(value,0,1)}])
var elite: Dictionary = {}
var spawn_origin: Vector2
var dodge_time: float = 0
var dodge_cooldown: float:
	get: return combat.dodge_cooldown if combat != null else 0.0
	set(value):
		if combat != null: combat.dodge_cooldown = value
var dodge_direction: Vector2 = Vector2.RIGHT
var last_direction: Vector2 = Vector2.RIGHT
var external_velocity := Vector2.ZERO
var body_radius: float:
	get: return 32.0 if faction==Factions.Team.BOSS else WorldNavigation.DEFAULT_RADIUS

func configure(game_world, data: SpeciesData, team: int, creature: CreatureInstance = null, affix: Dictionary = {}) -> void:
	world = game_world
	species = data
	faction = team
	individual = creature
	elite = affix
	identity = creature.persistent_id if creature != null else "runtime-"+str(get_instance_id())
	if creature != null: combat = creature.ensure_combat()
	elif team==Factions.Team.TRAINER and game_world.session.trainer_combat != null:
		combat = game_world.session.trainer_combat
	else:
		combat = CombatState.new()
		combat.configure(data,team,creature,affix)
	if team==Factions.Team.TRAINER:
		identity = "trainer"
		game_world.session.trainer_combat = combat
	combat.identity = identity
	combat.bind(self)
	stats = combat.stats
	health = combat.health
	energy = combat.energy
	statuses = combat.statuses
	triggers = combat.triggers
	types = combat.types
	abilities.actor = self
	abilities.cooldowns = combat.cooldowns
	health.died.connect(on_defeated)

func detach() -> void:
	abilities.interrupt()
	if individual != null: individual.sync_health()
	if health.died.is_connected(on_defeated): health.died.disconnect(on_defeated)
	if combat != null: combat.unbind(self)
	set_physics_process(false)

func _exit_tree() -> void: detach()

func _ready() -> void:
	add_to_group("actors")
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = body_radius
	shape.shape = circle
	add_child(shape)
	hurtbox = Area2D.new()
	hurtbox.collision_layer = 4
	hurtbox.collision_mask = 0
	hurtbox.set_meta("actor",self)
	var hurt_shape := CollisionShape2D.new()
	var hurt_circle := CircleShape2D.new()
	hurt_circle.radius = 21 if faction != Factions.Team.BOSS else 46
	hurt_shape.shape = hurt_circle
	hurtbox.add_child(hurt_shape)
	add_child(hurtbox)
	presentation = ActorPresentation.new()
	presentation.actor = self
	add_child(presentation)
	if faction != Factions.Team.TRAINER:
		brain = ActorBrain.new()
		brain.actor = self
	spawn_origin = global_position
	if health.current <= 0: on_defeated()

func _physics_process(delta: float) -> void:
	var stamp := CombatProfiler.start()
	combat.tick(delta)
	if individual != null: individual.sync_health()
	CombatProfiler.finish("actor.state",stamp)
	if health.current <= 0:
		if presentation.creature_animation != null: presentation.tick(delta)
		return
	stamp = CombatProfiler.start()
	abilities.tick(delta)
	if faction == Factions.Team.TRAINER: player_tick(delta)
	else: brain.tick(delta)
	CombatProfiler.finish("actor.decisions",stamp)
	stamp = CombatProfiler.start()
	velocity += external_velocity
	external_velocity = external_velocity.move_toward(Vector2.ZERO,600*delta)
	move_and_slide()
	global_position = global_position.clamp(Vector2(35,75),world.area.size-Vector2(35,35))
	if velocity.length_squared() > 4: last_direction = velocity.normalized()
	if individual != null: individual.health_ratio = health.current/health.maximum
	CombatProfiler.finish("actor.motion",stamp)
	stamp = CombatProfiler.start()
	presentation.tick(delta)
	CombatProfiler.finish("actor.presentation",stamp)

func player_tick(delta: float) -> void:
	if Settings.input_blocked():
		velocity = Vector2.ZERO
		return
	var direction := Input.get_vector("move_left","move_right","move_up","move_down")
	if Input.is_action_just_pressed("dodge",true) and dodge_cooldown <= 0 and energy.spend(24):
		dodge_direction = direction if direction != Vector2.ZERO else last_direction
		dodge_time = DODGE_DURATION
		dodge_cooldown = .85
		health.invulnerable = .3
		abilities.interrupt()
		triggers.fire("dodge")
		world.effects.burst(global_position,Color("90e7d3"),14)
		Audio.play("dodge",global_position)
	if dodge_time > 0:
		dodge_time -= delta
		velocity = dodge_direction * 490
	else: velocity = direction * stats.value("speed")
	if Input.is_action_pressed("attack",true):
		var target = world.aim_target(self,250)
		if target != null: abilities.cast("ability.pulse",target)

func apply_equipment() -> void:
	if individual != null: combat.apply_held_item(individual.held_item)

func ability_mods() -> Dictionary:
	return combat.ability_mods()

func ability_id(slot: int) -> String:
	var choices: Array = individual.abilities if individual != null else (species.abilities if species != null else ["ability.pulse"])
	return str(choices[slot]) if slot>=0 and slot<choices.size() else ""

func on_defeated() -> void:
	velocity = Vector2.ZERO
	external_velocity = Vector2.ZERO
	abilities.interrupt()
	if individual != null: individual.health_ratio = 0
	if is_instance_valid(presentation): presentation.fall()
	if is_instance_valid(hurtbox): hurtbox.set_deferred("monitorable",false)
	defeated.emit(self)
