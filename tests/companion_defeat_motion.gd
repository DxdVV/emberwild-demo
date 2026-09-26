extends Node

const DIRECTIONS := [Vector2.RIGHT,Vector2.DOWN,Vector2.UP,Vector2.LEFT]
var session
var subjects: Array[Actor] = []
var frame: int = 0
var seen: Dictionary = {}
var origins: Array[Vector2] = []
var identities: Array[String] = []
var deaths: int = 0
var grounded: bool = true
var preserved: bool = true
var caption: Label
var all_species: bool = false
var output_prefix: String = "companion-defeat"

func _ready() -> void:
	session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	session.hud.close_panel()
	session.hud.root.hide()
	session.autosave_remaining = 100000
	session.world.set_physics_process(false)
	for actor in session.world.actors:
		actor.set_physics_process(false)
		actor.presentation.hide()
	all_species = "--all-companions" in OS.get_cmdline_user_args()
	var displayed: Array = session.party.active_actors.duplicate()
	if all_species:
		output_prefix = "companion-defeat-all"
		var rng := RandomNumberGenerator.new()
		rng.seed = 851
		for id in ["species.briar","species.volt","species.solstice"]:
			var matching: Array = session.party.roster.filter(func(value): return value.species_id==id)
			var individual: CreatureInstance = matching[0] if not matching.is_empty() else CreatureInstance.create(Database.species[id],rng)
			if matching.is_empty(): session.party.add(individual)
			var actor: Actor = session.world.spawn_actor(id,Factions.Team.COMPANION,Vector2.ZERO,individual)
			actor.set_physics_process(false)
			displayed.append(actor)
	for actor in displayed:
		subjects.append(actor)
		identities.append(actor.identity)
		actor.presentation.show()
		actor.defeated.connect(func(_value): deaths += 1)
	session.world.camera.target = null
	session.world.camera.snap(Vector2(620,550))
	var overlay := CanvasLayer.new()
	add_child(overlay)
	caption = UIStyle.label("",18,UIStyle.PAPER)
	caption.position = Vector2(24,24)
	caption.add_theme_color_override("font_shadow_color",Color.BLACK)
	caption.add_theme_constant_override("shadow_outline_size",4)
	overlay.add_child(caption)

func _physics_process(delta: float) -> void:
	frame += 1
	if frame>960:
		if frame==961: Audio.shutdown()
		if frame==966:
			var valid := grounded and preserved and deaths==subjects.size()*4 and seen.size()==4
			for cycle in seen.values():
				for record in cycle.values(): valid = valid and record.walk.size()==6 and record.death.size()==6
			print("COMPANION DEFEAT ",JSON.stringify(seen)," deaths=",deaths," grounded=",grounded," preserved=",preserved," verified=",valid)
			get_tree().quit(0 if valid else 1)
		return
	var cycle := (frame-1)/240
	var local := (frame-1)%240
	var direction: Vector2 = DIRECTIONS[cycle]
	if local==0:
		seen[cycle] = {}
		origins.clear()
		for index in subjects.size():
			var actor := subjects[index]
			actor.combat.rest()
			# All approaches end on the same visible clearing, away from foreground trees.
			actor.position = (Vector2(310+index*140,570) if all_species else Vector2(440+index*300,570))-direction*(108 if all_species else 135)
			actor.last_direction = direction
			actor.presentation.recover()
			seen[cycle][str(actor.species.id)] = {"walk":{},"death":{}}
	caption.text = ["Профиль","Спереди","Со спины","Влево"][cycle]+" · "+("Пять видов существ" if all_species else "Уголёк и Ручеёк")+"\n"+("Шаги и взмахи крыльев" if local<100 else ("Шесть кадров падения · тело остаётся на земле" if local<180 else "Восстановление · возврат в стойку"))
	for index in subjects.size():
		var actor := subjects[index]
		var animation := actor.presentation.creature_animation
		actor.velocity = Vector2.ZERO
		if local<90:
			actor.velocity = direction*(72 if all_species else 90)
			actor.position += actor.velocity*delta
		if local==100:
			origins.append(actor.position)
			actor.health.invulnerable = 0
			actor.health.damage(1000000)
		if local==120: actor.presentation.fall()
		if local==180:
			actor.combat.rest()
			actor.presentation.recover()
		actor.presentation.tick(delta)
		if local==180: preserved = preserved and actor.health.current>0 and animation.current_clip==("walk" if animation.definition.autoplay else "idle") and not animation.defeated
		var record: Dictionary = seen[cycle][str(actor.species.id)]
		if animation.current_clip=="walk": record.walk[animation.current_frame] = true
		if local>=100 and local<180:
			record.death[animation.current_frame] = true
			var data: Dictionary = animation.definition.action_frames[animation.current_frame]
			var foot_height: float = animation.sprite.position.y+(data.anchor[1]-data.region[3]*.5)*animation.definition.scale_for(data,true)
			var landing: bool = animation.definition.autoplay and animation.dead_time<.2-.000001
			grounded = grounded and (foot_height>=-16.5 and foot_height<=.5 if landing else absf(foot_height)<=.5) and actor.position==origins[index]
			preserved = preserved and actor.health.current==0 and actor.identity==identities[index] and actor.individual in session.party.roster and actor.individual.health_ratio==0
	if local in [45,100,108,115,122,129,139,170,215]: capture.call_deferred(cycle,local)

func capture(cycle: int, local: int) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/%s-%d-%d.png"%[output_prefix,cycle,local])
