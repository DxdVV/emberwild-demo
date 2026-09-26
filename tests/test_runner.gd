extends Node

var passed: int = 0
var failures: Array[String] = []
var session

func _ready() -> void: run.call_deferred()

func check(condition: bool, title: String) -> void:
	if condition: passed += 1; print("PASS ",title)
	else: failures.append(title); push_error("FAIL "+title)

func frames(amount: int) -> void:
	for index in amount: await get_tree().physics_frame

func run() -> void:
	await get_tree().process_frame
	check(Database.errors.is_empty(),"registry validates every Resource")
	preload("res://tests/content_validation_checks.gd").new().run(check)
	preload("res://tests/combat_audio_checks.gd").new().run(check)
	check(Database.species.size()>=5 and Database.abilities.size()>=10,"slice content present")
	var stats := StatsComponent.new()
	stats.base = {"attack":100.0}
	stats.set_source("gear",[{"stat":"attack","op":"flat","value":10},{"stat":"attack","op":"add","value":.2},{"stat":"attack","op":"multiply","value":1.5}])
	check(is_equal_approx(stats.value("attack"),198),"flat/additive/multiplicative order")
	stats.set_source("freeze",[{"stat":"attack","op":"override","value":0}])
	check(stats.value("attack")==0,"zero override is respected")
	stats.remove_source("freeze")
	stats.remove_source("gear")
	check(stats.value("attack")==100,"modifier removal restores base")
	preload("res://tests/stats_compilation_checks.gd").new().run(check)
	preload("res://tests/frame_metrics_checks.gd").new().run(check)
	preload("res://tests/navigation_checks.gd").new().run(check)
	var health := HealthComponent.new()
	health.reset(100)
	health.shield = 20
	var result := health.damage(35)
	check(result.damage==15 and result.absorbed==20 and health.current==85,"shield absorption")
	health.invulnerable = .2
	check(health.damage(100).blocked and health.current==85,"invulnerability blocks damage")
	health.tick(.3)
	health.damage(200)
	health.heal(100)
	check(health.current==0,"healing cannot implicitly revive")
	var damage := DamageSystem.new()
	damage.rules = Database.rules
	var normal := damage.calculate({"attack":20,"power":2,"target_types":["neutral"]})
	var effective := damage.calculate({"attack":20,"power":2,"element":"fire","target_types":["nature"]})
	check(effective.final_damage>normal.final_damage,"data-driven type effectiveness")
	check(not Factions.hostile(Factions.Team.TRAINER,Factions.Team.COMPANION),"no friendly fire")
	check(Factions.hostile(Factions.Team.COMPANION,Factions.Team.BOSS),"companions target boss")
	var cd := CooldownComponent.new()
	var ability: AbilityData = Database.abilities["ability.flare"]
	cd.use(ability)
	check(not cd.available(ability),"cooldown consumes charge")
	cd.tick(ability.cooldown+.1)
	check(cd.available(ability),"charge recovers")
	var ready_save := cd.to_dict()
	check(ready_save.charges.is_empty() and cd.charges.has(ability.id),"saving ready cooldowns omits defaults without mutating the live charge cache")
	var ready_restored := CooldownComponent.new()
	ready_restored.restore(ready_save)
	check(ready_restored.available(ability) and ready_restored.to_dict()==ready_save,"fully replenished cooldowns round-trip in canonical form")
	cd.use(ability)
	var charging_save := cd.to_dict()
	ready_restored.restore(charging_save)
	check(not ready_restored.available(ability) and ready_restored.to_dict()==charging_save,"canonical saves retain spent charges and exact active recharge timers")
	var inv := InventoryData.new()
	var storage := InventoryData.new()
	storage.capacity = 0
	inv.add({"id":"test","base":"item.seed"})
	check(not inv.transfer(0,storage) and inv.items.size()==1,"full transfer is atomic")
	storage.capacity = 5
	check(inv.transfer(0,storage) and inv.items.is_empty() and storage.items.size()==1,"stash transfer preserves instance")
	var generator_a := ItemGenerator.new()
	var generator_b := ItemGenerator.new()
	generator_a.rng.seed = 87
	generator_b.rng.seed = 87
	check(generator_a.generate("item.prism",2)==generator_b.generate("item.prism",2),"loot deterministic by seed")
	preload("res://tests/loot_table_checks.gd").new().run(check)
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	var creature := CreatureInstance.create(Database.species["species.cinder"],rng)
	var identity := creature.persistent_id
	creature.level = 5
	check(Progression.evolve(creature) and creature.persistent_id==identity,"evolution preserves identity")
	var roundtrip := CreatureInstance.from_dict(creature.to_dict())
	check(roundtrip.to_dict()==creature.to_dict(),"creature serialization roundtrip")
	check(Progression.award(roundtrip,10000) and roundtrip.level>5,"multiple level progression")
	var payload := {"party":[creature.to_dict()],"inventory":storage.to_dict()}
	check(SaveStore.write(payload,"user://test-save.json"),"atomic save writes")
	check(SaveStore.read_save("user://test-save.json").party[0].id==identity,"save loads stable ID")
	check(SaveStore.migrate({"save_version":999}).is_empty(),"future saves rejected")
	check(SaveStore.migrate({"save_version":1,"party":[],"inventory":{}}).has("stash"),"v1 migration")
	check(SaveStore.migrate({"save_version":2,"party":[{"traits":"invalid"}],"inventory":{}}).is_empty(),"malformed nested save data rejected")
	check(SaveStore.migrate({"save_version":2,"party":[],"world_states":{"area.grove":{"drops":[{"position":"invalid"}]}}}).is_empty(),"malformed world snapshot rejected")
	SaveStore.write(payload,"user://test-save.json")
	var corrupt := FileAccess.open("user://test-save.json",FileAccess.WRITE)
	corrupt.store_string("{broken")
	corrupt.close()
	check(not SaveStore.read_save("user://test-save.json").is_empty(),"corrupt primary restores backup")
	session = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(session)
	get_tree().current_scene = session
	session.autosave_remaining = 100000
	session.hud.close_panel()
	await frames(4)
	check(session.world.actors.size()==3,"hub contains trainer and two companions")
	check(session.party.swap(2,0),"reserve can swap into first slot")
	check(not session.party.swap(0,0),"rapid repeat swap blocked")
	await frames(2)
	session.equip(0,2)
	check(session.party.roster[2].held_item.base=="item.prism","held item equips to chosen individual")
	session.change_area("area.grove",false)
	await frames(4)
	var world: GameWorld = session.world
	check(world.actors.size()>=15,"spawn director creates packs elite and boss")
	world.trainer.health.immortal = true
	var enemy := world.spawn_actor("species.briar",Factions.Team.WILD,world.trainer.position+Vector2(90,0))
	var before := enemy.health.current
	world.trainer.abilities.cast("ability.pulse",enemy)
	await frames(90)
	check(enemy.health.current<before,"windup projectile hurtbox damage integration")
	var affected = world.spawn_actor("species.briar",Factions.Team.WILD,Vector2(400,900))
	affected.statuses.apply("status.burn",world.trainer)
	affected.statuses.apply("status.burn",world.trainer)
	check(affected.statuses.entries["status.burn"].stacks==2,"status stacking")
	var original_speed: float = affected.stats.value("speed")
	affected.statuses.apply("status.slow",world.trainer)
	check(affected.stats.value("speed")<original_speed,"status stat modifier")
	affected.statuses.tick(10)
	check(affected.statuses.entries.is_empty() and affected.stats.value("speed")==original_speed,"status expiry removes modifier")
	var strong_chance := world.capture.chance(affected)
	affected.health.current = 1
	check(world.capture.chance(affected)>strong_chance,"capture benefits from weakening")
	var seals_before: int = session.inventory.seals
	check(not world.capture.attempt(affected,session.inventory,true).consumed and session.inventory.seals==seals_before,"full party does not consume capture item")
	world.focus_target = affected
	world.trainer.position = affected.position+Vector2(30,0)
	world.capture.rng.seed = 2
	for attempt in 10:
		if not is_instance_valid(affected) or not affected in world.actors: break
		world.capture_remaining = 0
		world.try_capture()
	check(session.quest.capture and session.party.roster.size()==4,"capture joins persistent party")
	await frames(2)
	var boss: Actor = world.actors.filter(func(actor): return actor.faction==Factions.Team.BOSS)[0]
	world.trainer.position = boss.position+Vector2(-150,0)
	boss.health.current = boss.health.maximum*.29
	await frames(4)
	check(boss.brain.boss_phase==2,"boss enters third phase")
	var hazard_count := world.get_children().filter(func(child): return child is GroundHazard).size()
	boss.brain.boss_time = 0
	await frames(2)
	check(world.get_children().filter(func(child): return child is GroundHazard).size()>hazard_count,"boss creates readable telegraphs")
	boss.health.damage(10000)
	check(session.quest.boss and world.drops.any(func(drop): return drop.item.base=="item.relic"),"boss grants unique build reward")
	world.trainer.position = boss.position
	world.interact()
	check(session.inventory.items.any(func(item): return item.base=="item.relic"),"world loot pickup")
	session.hud.show_inventory()
	check(get_tree().paused,"inventory pauses combat")
	session.hud.show_party()
	session.hud.show_settings()
	session.hud.show_camp()
	session.hud.show_debug()
	session.hud.close_panel()
	check(not get_tree().paused,"closing menus resumes combat")
	session.change_area("area.haven",false)
	await frames(3)
	check(session.party.active_actors.size()==2,"scene transition resummons only active companions")
	session.change_area("area.grove",false)
	await frames(3)
	check(not session.world.actors.any(func(actor): return actor.faction==Factions.Team.BOSS),"defeated boss stays defeated across area travel")
	var snapshot := WorldSnapshot.capture(session.world)
	var rng_state: int = session.world.capture.rng.state
	session.world.capture.rng.randf()
	WorldSnapshot.restore(session.world,snapshot)
	check(session.world.capture.rng.state==rng_state,"capture RNG state survives world snapshot without precision loss")
	var presentation: ActorPresentation = session.world.trainer.presentation
	Input.action_press("move_right")
	var seen_frames: Dictionary = {}
	for tick in 40:
		await frames(1)
		seen_frames[presentation.character_animation.previous_frame] = true
	Input.action_release("move_right")
	check(seen_frames.size()>=4,"player walk uses distinct animation frames")
	await frames(2)
	var before_distance: float = presentation.character_animation.travelled
	await frames(5)
	check(is_equal_approx(presentation.character_animation.travelled,before_distance),"stationary player does not advance walking distance")
	verify_locomotion(session.world.trainer)
	session.world.trainer.health.immortal = false
	session.world.trainer.health.invulnerable = 0
	session.world.trainer.health.damage(100000)
	session.hud.close_panel()
	check(get_tree().paused and not session.hud.panel.visible and presentation.character_animation.defeated,"defeat pauses combat and leaves the falling hero visible")
	var death_position: Vector2 = session.world.trainer.position
	var remaining_energy: float = session.world.trainer.energy.current
	var defeat_seen := {}
	Input.action_press("move_right")
	for tick in 65:
		await frames(1)
		defeat_seen[presentation.character_animation.defeat_frame] = true
	Input.action_release("move_right")
	check(defeat_seen.size()==6,"paused defeat presentation plays all six authored poses")
	check(not session.hud.world_labels.visible,"defeat hides unavailable world interaction prompts")
	check(session.world.trainer.position==death_position and session.world.trainer.energy.current==remaining_energy,"defeat presentation cannot move the trainer or tick combat state")
	check(presentation.character_animation.defeat_complete and not presentation.is_processing() and presentation.sprite.modulate.a==1,"defeat holds its final grounded pose and stops processing without fading")
	check(get_tree().paused and session.hud.panel.visible,"defeat cannot be dismissed into an unplayable state")
	session.revive()
	await frames(3)
	check(not get_tree().paused and session.world.trainer.health.current>0 and session.world.area.safe,"defeat recovery returns to safe haven")
	check(session.hud.world_labels.visible,"recovery restores world interaction prompts")
	await preload("res://tests/combat_persistence_checks.gd").new().run(session,check)
	preload("res://tests/combat_bounds_checks.gd").new().run(session,check)
	await preload("res://tests/arrival_checks.gd").new().run(session,check)
	await preload("res://tests/hero_defeat_checks.gd").new().run(session,check)
	preload("res://tests/creature_animation_checks.gd").new().run(session,check)
	preload("res://tests/directional_animation_checks.gd").new().run(session,check)
	preload("res://tests/companion_defeat_checks.gd").new().run(session,check)
	preload("res://tests/hero_combat_checks.gd").new().run(session,check)
	preload("res://tests/footstep_checks.gd").new().run(session,check)
	preload("res://tests/guardian_direction_checks.gd").new().run(session,check)
	preload("res://tests/presentation_budget_checks.gd").new().run(session,check)
	preload("res://tests/progression_checks.gd").new().run(session,check)
	preload("res://tests/evolution_checks.gd").new().run(session,check)
	preload("res://tests/layout_checks.gd").new().run(session,check)
	await preload("res://tests/settings_checks.gd").new().run(session,check)
	preload("res://tests/loot_label_checks.gd").new().run(session,check)
	await preload("res://tests/loot_hud_checks.gd").new().run(session,check)
	preload("res://tests/loot_marker_checks.gd").new().run(check)
	preload("res://tests/formation_checks.gd").new().run(session,check)
	await preload("res://tests/inspection_checks.gd").new().run(session,check)
	await preload("res://tests/live_status_checks.gd").new().run(session,check)
	await preload("res://tests/localization_checks.gd").new().run(session,check)
	await preload("res://tests/tooltip_checks.gd").new().run(session,check)
	preload("res://tests/save_hardening_checks.gd").new().run(session,check)
	preload("res://tests/item_ownership_checks.gd").new().run(session,check)
	await frames(100)
	check(session.world.actors.all(func(actor): return is_instance_valid(actor)),"early corpse removal leaves delayed cleanup safe")
	print("RESULT: ",passed," passed; ",failures.size()," failed")
	var report := FileAccess.open("res://build/tests.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed":passed,"failed":failures},"\t"))
	report.close()
	get_tree().quit(0 if failures.is_empty() else 1)

func verify_locomotion(actor: Actor) -> void:
	var motion := actor.presentation.character_animation
	var origin := actor.position
	actor.velocity = Vector2(180,0)
	actor.last_direction = Vector2.RIGHT
	motion.previous_position = actor.global_position
	actor.abilities.phase = AbilityController.Phase.WINDUP
	actor.position.x += 3
	motion.tick(1.0/60,false)
	check(motion.previous_frame in range(6,12),"moving cast keeps stepping instead of sliding in a frozen pose")
	motion.tick(1.0/60,false)
	check(motion.current_clip=="windup" and motion.action_frame>=0,"planted windup uses anticipation pose")
	actor.abilities.phase = AbilityController.Phase.RECOVERY
	motion.tick(1.0/60,false)
	check(motion.current_clip=="release" and motion.action_frame>=0,"planted release uses attack pose")
	actor.abilities.interrupt()
	var distance_before := motion.travelled
	motion.tick(1.0/60,false)
	check(motion.previous_frame in [18,19] and motion.travelled==distance_before,"blocked movement stops feet despite nonzero velocity")
	actor.position.x += 400
	motion.tick(1.0/60,false)
	check(motion.travelled==distance_before,"teleport does not advance walking cycle")
	actor.dodge_time = .2
	actor.position.x += 3
	motion.tick(1.0/60,false)
	check(motion.current_clip=="dodge" and motion.action_frame>=0 and motion.travelled==distance_before,"dodge has separate pose and does not advance footsteps")
	actor.dodge_time = 0
	motion.sprite.flip_h = false
	motion.set_frame(18)
	var right_offset := motion.sprite.position.x
	motion.sprite.flip_h = true
	motion.set_frame(18)
	check(right_offset!=0 and motion.sprite.position.x==-right_offset,"same-frame reversal mirrors the anchor without body drift")
	motion.travelled = 0
	for index in 60:
		actor.position.x += 3
		motion.tick(1.0/60,false)
	var sixty_hz_distance := motion.travelled
	var sixty_hz_frame := motion.previous_frame
	motion.travelled = 0
	for index in 30:
		actor.position.x += 6
		motion.tick(1.0/30,false)
	check(is_equal_approx(motion.travelled,sixty_hz_distance) and motion.previous_frame==sixty_hz_frame,"walking phase follows distance equally at 30 and 60 Hz")
	actor.position = origin
	actor.velocity = Vector2.ZERO
	motion.previous_position = actor.global_position
