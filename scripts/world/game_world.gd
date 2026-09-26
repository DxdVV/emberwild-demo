class_name GameWorld extends Node2D

signal message(text: String)
signal exit_requested(area_id: String)
signal trainer_defeated
var session
var arrival: Dictionary = {}
var area: AreaData
var seed_value: int = 48371
var trainer: Actor
var actors: Array = []
var hazards: Array[GroundHazard] = []
var focus_target
var damage := DamageSystem.new()
var capture := CaptureSystem.new()
var item_generator := ItemGenerator.new()
var navigation := WorldNavigation.new()
var effects: EffectsController
var combat_markers: CombatMarkers
var camera: CameraController
var population := SpawnDirector.new()
var entity_layer: Node2D
var drops: Array[Dictionary] = []
var capture_remaining: float = 0
var debug_draw: bool = false
var elapsed: float = 0
var removed_ids: Array[String] = []
var reveal_loot: bool = false
var labels_revision: int = 0
var loot_markers := LootMarkerBatch.new()

func refresh_labels() -> void:
	labels_revision += 1
	queue_redraw()

func _ready() -> void:
	Audio.bind_world(self)
	damage.rules = Database.rules
	damage.rng.seed = seed_value+1
	damage.resolved.connect(on_damage)
	capture.rng.seed = seed_value+2
	item_generator.rng.seed = seed_value+3
	item_generator.identity_scope = str(area.id)
	var terrain := WorldTerrain.new()
	terrain.area = area
	terrain.seed_value = seed_value
	add_child(terrain)
	entity_layer = Node2D.new()
	entity_layer.y_sort_enabled = true
	add_child(entity_layer)
	var environment := WorldEnvironment2D.new()
	environment.world = self
	entity_layer.add_child(environment)
	navigation.configure(area.size,environment.obstacles)
	# Build body-clearance profiles during area setup, never on the first combat frame.
	navigation.grid_for(WorldNavigation.DEFAULT_RADIUS)
	navigation.grid_for(32)
	effects = EffectsController.new()
	add_child(effects)
	camera = CameraController.new()
	add_child(camera)
	trainer = Actor.new()
	trainer.configure(self,null,Factions.Team.TRAINER)
	var trainer_data: Dictionary = arrival.get("trainer",{})
	trainer.position = arrival_position(trainer_data,area.layout.entry)
	trainer.last_direction = AreaLayout.point(trainer_data.get("direction",[1,0]))
	entity_layer.add_child(trainer)
	actors.append(trainer)
	trainer.defeated.connect(on_defeated)
	apply_trainer_equipment()
	if not arrival.is_empty():
		if not trainer_data.get("combat",{}).is_empty(): trainer.combat.restore(trainer_data.combat)
		else: trainer.health.current = clampf(float(trainer_data.get("health",180)),0,trainer.health.maximum)
	camera.target = trainer
	camera.set_bounds(area.size)
	camera.snap(trainer.position)
	var listener := AudioListener2D.new()
	trainer.add_child(listener)
	listener.make_current()
	session.party.world = self
	session.party.summon(arrival.get("companions",{}),not arrival.is_empty())
	population.populate(self)
	WorldSnapshot.restore(self,session.world_states.get(str(area.id),{}))
	combat_markers = CombatMarkers.new()
	combat_markers.world = self
	add_child(combat_markers)
	arrival = {}
	Settings.changed.connect(queue_redraw)
	queue_redraw()

func arrival_position(record: Dictionary, fallback: Vector2) -> Vector2:
	if not record.has("position"): return fallback
	var desired := AreaLayout.point(record.position).clamp(Vector2(35,75),area.size-Vector2(35,35))
	var safe := navigation.safe_position_near(desired)
	return fallback if safe==Vector2.INF else safe

func spawn_actor(species_id: String, faction: int, at: Vector2, individual: CreatureInstance = null, affix: Dictionary = {}, direction: Vector2 = Vector2.RIGHT) -> Actor:
	var actor := Actor.new()
	actor.configure(self,Database.species[species_id],faction,individual,affix)
	actor.position = at
	actor.last_direction = direction
	entity_layer.add_child(actor)
	actors.append(actor)
	actor.defeated.connect(on_defeated)
	return actor

func remove_actor(actor: Actor) -> void:
	actors.erase(actor)
	if focus_target == actor: focus_target = null
	actor.detach()
	actor.queue_free()

func notice(text: String) -> void: message.emit(text)

func aim_target(source: Actor, reach: float):
	if TargetingSystem.valid(source,focus_target) and source.global_position.distance_to(focus_target.global_position)<=reach: return focus_target
	var target = TargetingSystem.nearest(source,actors,get_global_mouse_position(),80)
	if target != null and source.global_position.distance_to(target.global_position)<=reach: return target
	return TargetingSystem.nearest(source,actors,source.global_position,reach)

func launch(source: Actor, target: Actor, ability: AbilityData, context: Dictionary = {}) -> void:
	if not TargetingSystem.valid(source,target): return
	Audio.play_ability(ability,"cast",source.global_position)
	var mods := source.ability_mods()
	context = context.duplicate()
	context["chains"] = int(mods.get("chains",0))
	if ability.delivery!="projectile":
		var direction := source.global_position.direction_to(target.global_position)
		var victims: Array = TargetingSystem.cone(source,actors,direction,ability.reach,deg_to_rad(ability.cone_angle)) if ability.delivery=="cone" else TargetingSystem.area(source,actors,source.global_position,ability.radius)
		effects.ability_area(source.global_position,direction,ability)
		AbilityResolver.resolve(self,source,victims,ability,context)
		camera.impulse(1.5)
		return
	var targets: Array = [target]
	for index in int(mods.get("projectiles",1))-1:
		var extra = TargetingSystem.nearest(source,actors,target.global_position,150,targets)
		if extra != null: targets.append(extra)
	for selected in targets:
		var projectile := AbilityProjectile.new()
		projectile.world = self
		projectile.source_ref = weakref(source)
		projectile.target_ref = weakref(selected)
		projectile.ability = ability
		projectile.context = context.duplicate(true)
		projectile.position = source.global_position
		add_child(projectile)

func resolve_hit(source, target, ability: AbilityData, context: Dictionary) -> void:
	if not TargetingSystem.valid(source,target): return
	var targets := TargetingSystem.area(source,actors,target.global_position,ability.radius) if ability.radius>0 else [target]
	AbilityResolver.resolve(self,source,targets,ability,context)
	if ability.radius>0: camera.impulse(1.5)

func hazard(source: Actor, at: Vector2, radius: float, delay: float) -> void:
	var node := GroundHazard.new()
	node.world = self
	node.source_ref = weakref(source)
	node.position = at
	node.radius = radius
	node.duration = delay
	add_child(node)

func spawn_adds(at: Vector2, amount: int) -> void:
	for index in amount: spawn_actor("species.cinder",Factions.Team.HOSTILE,at+Vector2(-90+index*180,70))

func on_damage(request: Dictionary, result: Dictionary) -> void:
	session.combat_damage += result.final_damage
	session.combat_events += 1
	var target = actors.filter(func(actor): return actor.identity==request.target_id)
	if target.is_empty(): return
	var color := Color("ffe4a1") if result.critical else Color("f1eee0")
	if result.effectiveness>1: color = Color("ffb966")
	if result.final_damage>0:
		effects.floating(target[0].global_position,str(int(ceilf(result.final_damage)))+("!" if result.critical else ""),color)
	if result.final_damage>0 or result.get("absorbed",0)>0:
		var ability: AbilityData = Database.abilities.get(str(request.get("ability","")))
		if ability!=null: Audio.play_ability(ability,"impact",target[0].global_position)
		else: Audio.play("hit",target[0].global_position,-7) # Quieter periodic damage.

func on_defeated(actor: Actor) -> void:
	if actor.faction == Factions.Team.TRAINER:
		trainer_defeated.emit()
		return
	if actor.faction == Factions.Team.COMPANION:
		notice(tr("notice.defeated")%tr(actor.species.name_key))
		return
	if actor.identity.begins_with("encounter:") and actor.identity not in removed_ids: removed_ids.append(actor.identity)
	var xp := 25 + actor.stats.level*8
	var loot_table := "common"
	if not actor.elite.is_empty():
		xp *= 3
		session.quest["elite"] = true
		loot_table = "elite"
	if actor.faction == Factions.Team.BOSS:
		xp = 350
		session.quest["boss"] = true
		loot_table = "boss"
		notice(tr("notice.victory"))
	var dropped := item_generator.generate_drop(loot_table,actor.stats.level)
	if not dropped.is_empty(): drop_item(actor.global_position,dropped)
	session.inventory.currency += xp/3
	for creature in session.party.roster:
		if Progression.award(creature,xp): notice(tr("notice.level")%[tr(Database.species[creature.species_id].name_key),creature.level])
	effects.floating(actor.global_position,"+"+str(xp)+" XP",Color("addec1"))
	var corpse: WeakRef = weakref(actor)
	# Corpse animation and cleanup must consume the same paused game time.
	get_tree().create_timer(1.5,false).timeout.connect(func():
		var expired_actor = corpse.get_ref()
		if is_instance_valid(expired_actor): remove_actor(expired_actor))

func drop_item(at: Vector2, item: Dictionary) -> void:
	drops.append({"at":at,"item":item})
	Audio.play("loot",at)
	refresh_labels()

func apply_trainer_equipment() -> void:
	for key in trainer.triggers.sources.keys():
		if str(key).begins_with("equipment:"): trainer.triggers.set_source(key,[])
	for slot in session.equipment:
		var item: Dictionary = session.equipment[slot]
		trainer.stats.set_source("equipment:"+slot,ItemGenerator.modifiers(item))
		if Database.items.has(item.get("base","")):
			trainer.triggers.set_source("equipment:"+slot,Database.items[item.base].triggers)
			trainer.combat.ability_modifier_sources["equipment:"+slot] = Database.items[item.base].ability_mods.duplicate()
	var ratio := trainer.health.current/trainer.health.maximum
	trainer.health.reset(trainer.stats.value("health"),ratio)

func _physics_process(delta: float) -> void:
	elapsed += delta
	capture_remaining = maxf(0,capture_remaining-delta)
	session.party.tick(delta)
	if trainer.health.current<=0: return
	if Settings.input_blocked(): return
	var show_all := Input.is_action_pressed("show_all_loot")
	if show_all!=reveal_loot:
		reveal_loot = show_all
		refresh_labels()
	if Input.is_action_just_pressed("focus",true):
		focus_target = TargetingSystem.nearest(trainer,actors,get_global_mouse_position(),85)
	if Input.is_action_just_pressed("companion_mode",true):
		session.party.cycle_mode()
		notice(tr("notice.mode")%tr("mode."+str(session.party.mode)))
	for index in 2:
		if Input.is_action_just_pressed("ability_one" if index==0 else "ability_two",true):
			if index<session.party.active_actors.size():
				var actor = session.party.active_actors[index]
				if is_instance_valid(actor):
					var target = aim_target(actor,Database.abilities[actor.ability_id(1)].reach)
					if target != null and not actor.abilities.cast(actor.ability_id(1),target): notice(tr("notice.ability_unavailable"))
	for index in 4:
		for slot in 2:
			var action: String = "swap_"+["one","two","three","four"][index] if slot==0 else "swap_second_"+str(index+1)
			if Input.is_action_just_pressed(action,true) and not session.party.swap(index,slot): notice(tr("notice.swap_unavailable"))
	if Input.is_action_just_pressed("capture",true): try_capture()
	if Input.is_action_just_pressed("interact",true): interact()
	if Input.is_action_just_pressed("potion",true) and session.inventory.potions>0:
		if trainer.health.current<trainer.health.maximum:
			session.inventory.potions -= 1
			trainer.health.heal(trainer.health.maximum*.5)
			effects.burst(trainer.position,Color("8cffbf"),18)
func try_capture() -> void:
	if capture_remaining>0: return
	var target = aim_target(trainer,Database.rules.capture_range)
	if target == null: notice(tr("notice.capture_target")) ; return
	var result := capture.attempt(target,session.inventory,session.party.roster.size()>=Database.rules.party_limit)
	if not result.consumed: notice(tr("notice.capture_unavailable")) ; return
	capture_remaining = Database.rules.capture_cooldown
	effects.burst(target.position,Color("a4e9db"),25)
	Audio.play("capture",target.position)
	if result.success:
		var creature := CreatureInstance.create(target.species,capture.rng)
		creature.level = target.stats.level
		creature.history = {"captured_in":str(area.id),"seed":seed_value}
		session.party.add(creature)
		session.quest["capture"] = true
		if target.identity.begins_with("encounter:"): removed_ids.append(target.identity)
		notice(tr("notice.joined")%tr(target.species.name_key))
		remove_actor(target)
	else: notice(tr("notice.escaped")%int(result.chance*100))

func visible_drops() -> Array[Dictionary]:
	return drops.filter(func(drop): return reveal_loot or Settings.loot_filter.accepts(drop.item))

func visible_drop_indices() -> Array[int]:
	var result: Array[int] = []
	for index in drops.size():
		if reveal_loot or Settings.loot_filter.accepts(drops[index].item): result.append(index)
	return result

func pickup_candidate() -> int:
	var selected := -1
	var distance := 10000.0
	for index in drops.size():
		if not reveal_loot and not Settings.loot_filter.accepts(drops[index].item): continue
		var candidate := trainer.position.distance_squared_to(drops[index].at)
		if candidate<distance: selected=index; distance=candidate
	return selected

func interact() -> void:
	var index := pickup_candidate()
	if index>=0:
		var item: Dictionary = drops[index].item
		if session.inventory.add(item,false):
			drops.remove_at(index)
			refresh_labels()
			session.inventory.changed.emit()
			notice(tr("notice.received")%tr(Database.items[item.base].name_key))
		else: notice(tr("notice.full"))
		return
	for interaction in area.layout.interactions:
		if trainer.position.distance_to(AreaLayout.point(interaction.at))>=float(interaction.radius): continue
		if interaction.action=="rest":
			session.party.rest()
			trainer.combat.rest()
			trainer.abilities.interrupt()
			for actor in session.party.active_actors:
				if is_instance_valid(actor):
					actor.abilities.interrupt()
					actor.presentation.recover()
					actor.hurtbox.set_deferred("monitorable",true)
			notice(tr("notice.rested"))
			Audio.play("capture")
		elif interaction.action=="exit": exit_requested.emit(interaction.target)
		elif interaction.action=="camp": session.open_camp()
		return

func _draw() -> void:
	loot_markers.update(visible_drops())
	if loot_markers.instances.instance_count>0: draw_multimesh(loot_markers.instances,null)

func interaction_markers() -> Dictionary:
	var key := Settings.inputs.label("interact")+" · "
	var result := {}
	for interaction in area.layout.interactions:
		result[AreaLayout.point(interaction.at)+Vector2(0,35)] = key+tr(interaction.label)
	return result
