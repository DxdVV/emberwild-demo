extends Node

# A bounded player-input pilot, not a substitute for human gameplay acceptance.
# No healing grants, forced damage, invulnerability, encounter edits or teleporting.
var session
var frames: int = 0
var stage: int = 0
var waypoint: int = 0
var route: Array[Vector2] = [Vector2(620,620),Vector2(850,800),Vector2(1190,1000),Vector2(1570,1140),Vector2(1190,1000),Vector2(1280,750),Vector2(1110,450),Vector2(1400,460),Vector2(1630,480),Vector2(1830,680),Vector2(2050,900)]
var team_improved: bool = false
var return_index: int = 0
var rest_trips: int = 0
var return_route: Array[Vector2] = [Vector2(1400,460),Vector2(1110,450),Vector2(940,520),Vector2(850,800),Vector2(620,620),Vector2(170,510)]
var finished: bool = false
var pulses: Dictionary = {}
var events: Array[Dictionary] = []
var commands: int = 0
var dodges: int = 0
var swaps: int = 0
var phases: Dictionary = {}
var walked: Dictionary = {}
var save_path: String = ""
var escape_goal := Vector2.INF
var timing_enabled: bool = false
var timing_started: bool = false
var frame_metrics := FrameMetrics.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	timing_enabled = "--journey-timing" in OS.get_cmdline_user_args()
	session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	session.autosave_remaining = 100000
	save_path = SaveStore.storage_path
	SaveStore.storage_path = "user://journey-runtime.json"
	session.hud.close_panel(true)
	# Equip only the three items a normal new journey already owns.
	session.equip(2,0)
	session.equip(0,0)
	session.equip(0,1)
	record("departure")
	if timing_enabled:
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
		RenderingServer.viewport_set_measure_render_time(session.world_viewport.get_viewport_rid(),true)

func _process(_delta: float) -> void:
	if not timing_enabled or finished or frames<180: return
	var now := Time.get_ticks_usec()
	if not timing_started:
		frame_metrics.begin(now,Engine.get_frames_drawn(),Engine.get_physics_frames())
		timing_started = true
		return
	var view: RID = session.world_viewport.get_viewport_rid()
	var root_view := get_viewport().get_viewport_rid()
	frame_metrics.sample(now,Engine.get_frames_drawn(),Engine.get_physics_frames(),get_window().has_focus(),RenderingServer.get_frame_setup_time_cpu()+RenderingServer.viewport_get_measured_render_time_cpu(view)+RenderingServer.viewport_get_measured_render_time_cpu(root_view),RenderingServer.viewport_get_measured_render_time_gpu(view)+RenderingServer.viewport_get_measured_render_time_gpu(root_view))

func record(event: String) -> void:
	var entry := {"event":event,"seconds":frames/60.0,"area":str(session.world.area.id),"position":[session.world.trainer.position.x,session.world.trainer.position.y],"trainer_hp":session.world.trainer.health.current,"party":session.party.roster.map(func(creature): return {"species":creature.species_id,"level":creature.level,"hp":creature.health_ratio}),"seals":session.inventory.seals,"potions":session.inventory.potions,"quest":session.quest.duplicate()}
	events.append(entry)
	print("JOURNEY ",JSON.stringify(entry))
	capture.call_deferred(event)

func capture(event: String) -> void:
	# PNG readback/encoding must not contaminate the interactive timing run.
	if DisplayServer.get_name()=="headless" or timing_enabled: return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/journey-"+event+".png")

func pulse(action: String) -> void:
	if pulses.has(action): return
	Input.action_press(action)
	pulses[action] = 3

func move(direction: Vector2) -> void:
	for action in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)
	if direction.x<0: Input.action_press("move_left",-direction.x)
	if direction.x>0: Input.action_press("move_right",direction.x)
	if direction.y<0: Input.action_press("move_up",-direction.y)
	if direction.y>0: Input.action_press("move_down",direction.y)

func direction_to(goal: Vector2) -> Vector2:
	var trainer: Actor = session.world.trainer
	var navigation: WorldNavigation = session.world.navigation
	# Manual player collision can enter the AI grid's two-pixel safety margin.
	# Step out through ordinary input; never warp the trainer to a grid cell.
	if not navigation.point_clear(trainer.position,trainer.body_radius):
		var safe := navigation.safe_position_near(trainer.position,trainer.body_radius)
		if safe!=Vector2.INF: return trainer.position.direction_to(safe)
	return navigation.direction(trainer.position,goal,trainer.body_radius)

func _physics_process(_delta: float) -> void:
	if finished: return
	frames += 1
	for action in pulses.keys():
		pulses[action] -= 1
		if pulses[action]<=0:
			Input.action_release(action)
			pulses.erase(action)
	Input.action_release("attack")
	move(Vector2.ZERO)
	if frames>21600: finish("deadline"); return
	if session.transitioning: return
	var world: GameWorld = session.world
	var trainer: Actor = world.trainer
	if trainer.health.current<=0: finish("trainer_defeated"); return
	if stage==2:
		if world.area.id==&"area.haven": stage = 3; record("returned-for-rest"); return
		var home := return_route[mini(return_index,return_route.size()-1)]
		if trainer.position.distance_to(home)<35: return_index += 1
		move(direction_to(home))
		if return_index>=return_route.size() and frames%15==0: pulse("interact")
		return
	if stage==3:
		var spring := Vector2(720,440)
		move(direction_to(spring))
		if trainer.position.distance_to(spring)<95:
			if trainer.health.current==trainer.health.maximum and session.party.roster.all(func(creature): return creature.health_ratio>=1):
				stage = 4
				waypoint = 0
				record("rested")
			elif frames%15==0: pulse("interact")
		return
	if stage in [0,4]:
		if world.area.id==&"area.grove":
			stage = 1 if stage==0 else 5
			record("grove" if stage==1 else "grove-return")
		else:
			var exit_at := Vector2(1060,650)
			move(direction_to(exit_at))
			if trainer.position.distance_to(exit_at)<90 and frames%15==0: pulse("interact")
			return
	walked[trainer.presentation.character_animation.previous_frame] = true
	if not team_improved and session.quest.capture and session.party.roster.size()>3 and session.party.swap_remaining<=0:
		# Evaluate the captured fire creature for the grove's nature encounters.
		if session.party.roster[3].species_id=="species.cinder" and session.party.swap(3,1):
			if session.unequip_held(1): session.equip(session.inventory.items.size()-1,3)
			team_improved = true
			swaps += 1
			record("captured-build")
	var target: Actor
	var distance := INF
	for actor in world.actors:
		if not Factions.hostile(trainer.faction,actor.faction) or actor.health.current<=0: continue
		var current := trainer.position.distance_to(actor.position)
		if current<distance: target = actor; distance = current
		if actor.faction==Factions.Team.BOSS and current<450: phases[actor.brain.boss_phase] = true
	# Explicit player focus keeps native desktop-pointer position out of the pilot's
	# targeting decisions. This is the same selection available through right-click.
	world.focus_target = target if distance<330 else null
	if frames%6==0 and trainer.health.current<trainer.health.maximum*.6 and session.inventory.potions>0: pulse("potion")
	if frames%30==0:
		for slot in session.party.active_actors.size():
			var ally: Actor = session.party.active_actors[slot]
			if ally.health.current<ally.health.maximum*.15:
				for index in session.party.roster.size():
					if index not in session.party.active_indices and session.party.roster[index].health_ratio>.5 and session.party.swap_remaining<=0:
						# The same party action used by menu buttons, including its cooldown.
						if session.party.swap(index,slot): swaps += 1
						break
	var goal: Vector2 = route[mini(waypoint,route.size()-1)]
	if target!=null and distance<330:
		Input.action_press("attack")
		if distance>225: goal = target.position
		elif distance<175: goal = trainer.position+(trainer.position-target.position).normalized()*100
		else: goal = trainer.position
		if frames%30==0:
			if not session.quest.capture and target.faction==Factions.Team.WILD and distance<Database.rules.capture_range and world.capture_remaining<=0 and world.capture.chance(target)>.25: pulse("capture")
			for slot in session.party.active_actors.size():
				var ally: Actor = session.party.active_actors[slot]
				var ability: AbilityData = Database.abilities[ally.ability_id(1)]
				if ally.health.current>0 and ally.abilities.cooldowns.available(ability) and ally.energy.current>=ability.cost:
					pulse("ability_one" if slot==0 else "ability_two")
					commands += 1
	else:
		var loot: Dictionary = {}
		var loot_distance := 270.0
		for drop in world.visible_drops():
			var current := trainer.position.distance_to(drop.at)
			if session.quest.boss and drop.item.base=="item.relic": loot_distance = current; loot = drop; break
			if current<loot_distance: loot_distance = current; loot = drop
		if not loot.is_empty():
			goal = loot.at
			if loot_distance<90 and frames%15==0: pulse("interact")
		elif trainer.position.distance_to(goal)<35:
			if waypoint<route.size():
				record("stage-%d-waypoint-%02d"%[stage,waypoint])
				waypoint += 1
				if (waypoint==7 and stage==1) or (waypoint==9 and stage==5 and session.quest.elite and rest_trips<2):
					stage = 2
					return_index = 1 if waypoint==7 else 0
					rest_trips += 1
					record("rest-trip")
					return
			if waypoint>=route.size() and session.quest.boss: finish("cleared"); return
	# React to the same committed ground circles that a player can see.
	var threats: Array[GroundHazard] = []
	for hazard: GroundHazard in world.hazards:
		if not hazard.activated and not hazard.is_queued_for_deletion() and trainer.position.distance_to(hazard.position)<hazard.radius+250:
			threats.append(hazard)
	if threats.is_empty(): escape_goal = Vector2.INF
	elif not safe_from_hazards(trainer.position,threats) or escape_goal!=Vector2.INF:
		# A three-wave attack needs one destination outside every pending circle.
		# Replacing the goal for each circle steered the pilot back into earlier waves.
		if escape_goal==Vector2.INF or not safe_from_hazards(escape_goal,threats):
			escape_goal = Vector2.INF
			var best := INF
			for hazard in threats:
				for index in 32:
					var candidate := hazard.position+Vector2.from_angle(index*TAU/32)*(hazard.radius+40)
					var cost := trainer.position.distance_squared_to(candidate)
					if cost<best and safe_from_hazards(candidate,threats) and world.navigation.segment_clear(trainer.position,candidate,trainer.body_radius):
						escape_goal = candidate
						best = cost
		if escape_goal!=Vector2.INF:
			goal = escape_goal
			if not safe_from_hazards(trainer.position,threats) and trainer.dodge_cooldown<=0 and trainer.energy.current>=24:
				pulse("dodge")
				dodges += 1
	var direction := direction_to(goal) if trainer.position.distance_to(goal)>5 else Vector2.ZERO
	move(direction)
	if frames%1800==0: record("minute-%02d"%(frames/3600))

func safe_from_hazards(at: Vector2, threats: Array[GroundHazard]) -> bool:
	for hazard in threats:
		if at.distance_to(hazard.position)<hazard.radius+25: return false
	return true

func finish(reason: String) -> void:
	if finished: return
	finished = true
	if timing_enabled:
		var timing := frame_metrics.report()
		timing["diagnostic_args"] = OS.get_cmdline_args()
		timing["headless"] = DisplayServer.get_name()=="headless"
		timing["renderer"] = RenderingServer.get_video_adapter_name()
		timing["window_size"] = [get_window().size.x,get_window().size.y]
		timing["vsync_mode"] = DisplayServer.window_get_vsync_mode()
		timing["max_fps"] = Engine.max_fps
		timing["effects_quality"] = Settings.effects_quality
		timing["source"] = FileAccess.get_sha256("res://tests/journey_runtime.gd")
		var timing_file := FileAccess.open("res://build/demo-journey-timing.json",FileAccess.WRITE)
		timing_file.store_string(JSON.stringify(timing,"\t"))
		timing_file.close()
	move(Vector2.ZERO)
	Input.action_release("attack")
	for action in pulses: Input.action_release(action)
	record(reason)
	var has_reward: bool = session.inventory.items.any(func(item): return item.base=="item.relic")
	var success: bool = reason=="cleared" and session.demo_completed() and has_reward and walked.size()>=12 and phases.size()==3 and stage==5 and team_improved
	var saved := false
	var resumed := false
	if success:
		var expected: Dictionary = JSON.parse_string(JSON.stringify(session.save_data()))
		saved = session.save_game(false) and SavedJourney.valid(SaveStore.read_save("",SavedJourney.valid))
		if saved and session.load_game():
			var actual: Dictionary = JSON.parse_string(JSON.stringify(session.save_data()))
			success = success and session.demo_completed()
			resumed = actual.party==expected.party and actual.party_state==expected.party_state and actual.inventory==expected.inventory and actual.quest==expected.quest and actual.active==expected.active and is_equal_approx(actual.trainer.health,expected.trainer.health) and actual.trainer.position==expected.trainer.position and actual.trainer.direction==expected.trainer.direction and not session.world.actors.any(func(actor): return actor.faction==Factions.Team.BOSS)
			if not resumed:
				for data in [["before",expected],["after",actual]]:
					var snapshot := FileAccess.open("res://build/journey-save-"+data[0]+".json",FileAccess.WRITE)
					snapshot.store_string(JSON.stringify(data[1],"\t"))
					snapshot.close()
	var report := {"success":success and saved and resumed,"reason":reason,"frames":frames,"seconds":frames/60.0,"waypoints":waypoint,"rest_trips":rest_trips,"quests":session.quest.duplicate(),"reward_collected":has_reward,"command_requests":commands,"dodge_requests":dodges,"swaps":swaps,"combat_events":session.combat_events,"boss_phases":phases.keys(),"walking_frames":walked.size(),"saved":saved,"resumed":resumed,"events":events}
	report["actors"] = session.world.actors.map(func(actor): return {"species":str(actor.species.id) if actor.species!=null else "trainer","faction":actor.faction,"hp":actor.health.current,"position":[actor.position.x,actor.position.y],"mode":actor.brain.mode if actor.brain!=null else -1,"state":actor.brain.state if actor.brain!=null else -1})
	report["pilot"] = {"stage":stage,"clear":session.world.navigation.point_clear(session.world.trainer.position),"safe":str(session.world.navigation.safe_position_near(session.world.trainer.position)),"direction":str(direction_to(route[mini(waypoint,route.size()-1)])),"velocity":str(session.world.trainer.velocity),"drops":session.world.drops.map(func(drop): return str(drop.at))}
	var file := FileAccess.open("res://build/journey-runtime.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	SaveStore.storage_path = save_path
	if timing_enabled and success:
		session.hud.show_demo_complete()
		for index in 5: await get_tree().process_frame
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://build/demo-journey-complete.png")
	Audio.shutdown()
	for index in 5: await get_tree().process_frame
	print("JOURNEY RUNTIME ",JSON.stringify(report)," verified=",report.success)
	get_tree().quit(0 if report.success else 1)
