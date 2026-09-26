extends Node

var session
var caption: Label
var failed: bool = false
var kind: String = "boss"

func _ready() -> void: run.call_deferred()

func run() -> void:
	if "--corpse-kind=wild" in OS.get_cmdline_user_args(): kind = "wild"
	session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	session.hud.close_panel()
	session.hud.root.hide()
	session.autosave_remaining = 100000
	session.world.set_physics_process(false)
	for actor in session.world.actors:
		actor.set_physics_process(false)
		actor.presentation.hide()
	session.world.camera.target = null
	session.world.camera.snap(Vector2(620,550))
	var overlay := CanvasLayer.new()
	add_child(overlay)
	caption = UIStyle.label("Страж · падение → пауза → продолжение",18,UIStyle.PAPER)
	caption.position = Vector2(24,24)
	caption.add_theme_color_override("font_shadow_color",Color.BLACK)
	caption.add_theme_constant_override("shadow_outline_size",4)
	overlay.add_child(caption)
	var boss: Actor = session.world.spawn_actor("species.guardian" if kind=="boss" else "species.cinder",Factions.Team.BOSS if kind=="boss" else Factions.Team.WILD,Vector2(620,590))
	boss.last_direction = Vector2.RIGHT
	boss.presentation.tick(0)
	boss.health.damage(100000)
	var corpse: WeakRef = weakref(boss)
	var reward: int = session.inventory.currency
	var loot: int = session.world.drops.size()
	await get_tree().create_timer(.25,false).timeout
	var elapsed := boss.presentation.creature_animation.dead_time
	var pose := boss.presentation.creature_animation.current_frame
	get_tree().paused = true
	caption.text = "Пауза · тело и кадр падения сохраняются"
	await capture("paused-before")
	await get_tree().create_timer(1.8,true).timeout
	var current: Actor = corpse.get_ref()
	var pause_preserved := is_instance_valid(current)
	if pause_preserved:
		pause_preserved = current.presentation.creature_animation.dead_time==elapsed and current.presentation.creature_animation.current_frame==pose
	print("CORPSE PAUSE pause_preserved=",pause_preserved)
	failed = not pause_preserved
	await capture("paused-after")
	get_tree().paused = false
	caption.text = "Продолжение · падение завершается до удаления тела"
	await get_tree().create_timer(.65,false).timeout
	current = corpse.get_ref()
	var finished := is_instance_valid(current)
	if finished:
		var animation := current.presentation.creature_animation
		var clip: Array = animation.definition.clips[animation.definition.clip_id("death",animation.facing)]
		finished = animation.dead_time==animation.definition.death_duration and animation.current_frame==clip[-1]
	print("CORPSE PAUSE finished_before_cleanup=",finished)
	failed = failed or not finished
	await capture("finished")
	await get_tree().create_timer(.8,false).timeout
	var cleaned := not is_instance_valid(corpse.get_ref())
	var reward_once: bool = session.quest.boss==(kind=="boss") and session.inventory.currency==reward and session.world.drops.size()==loot and (kind!="boss" or loot==1)
	print("CORPSE PAUSE cleanup=",cleaned," reward_once=",reward_once," verified=",not failed and cleaned and reward_once)
	Audio.shutdown()
	for index in 5: await get_tree().process_frame
	get_tree().quit(1 if failed or not cleaned or not reward_once else 0)

func capture(suffix: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/corpse-pause-%s-%s.png"%[kind,suffix])
