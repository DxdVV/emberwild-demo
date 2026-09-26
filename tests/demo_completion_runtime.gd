extends Node

var session
var checks: int = 0
var failures: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print("DEMO COMPLETION ",label," verified=",value)

func settle() -> void:
	for frame in 5: await get_tree().process_frame

func button(text: String) -> Button:
	for candidate in session.hud.panel_content.find_children("*","Button",true,false):
		if candidate.text==text: return candidate
	return null

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/demo-"+label+".png")

func run() -> void:
	var locale := Settings.locale
	session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	session.autosave_remaining = 100000
	for mask in 8:
		session.quest = {"capture":bool(mask&1),"elite":bool(mask&2),"boss":bool(mask&4)}
		check(session.demo_completed()==(mask==7),"all three objectives required: "+str(mask))
	session.quest = {"capture":true,"elite":false,"boss":true}
	session.open_camp()
	check(button(tr("demo.explore"))==null and button(tr("camp.expedition"))!=null,"unfinished journey opens ordinary camp")
	session.hud.show_demo_complete()
	check(button(tr("demo.explore"))==null,"direct results request cannot declare an unfinished journey complete")
	session.quest.elite = true
	var before: Dictionary = session.save_data().duplicate(true)
	Settings.set_locale("ru",false)
	session.open_camp()
	await settle()
	check(get_tree().paused and button(tr("demo.explore"))!=null,"completed journey opens paused ending from camp")
	check(button(tr("menu.quit"))!=null and button(tr("camp.title"))!=null,"ending offers camp and existing save-and-quit path")
	check(session.save_data()==before,"reading results does not change gameplay or award rewards twice")
	await capture("complete-ru")
	Settings.set_locale("en",false)
	await settle()
	check(button("Keep exploring")!=null,"open ending rebuilds in English")
	await capture("complete-en")
	button(tr("demo.explore")).pressed.emit()
	check(not get_tree().paused and not session.hud.panel.visible,"continue button resumes exploration")
	session.hud.show_pause()
	check(button(tr("demo.results"))!=null,"completed journey exposes results from pause menu")
	button(tr("demo.results")).pressed.emit()
	check(button(tr("camp.title"))==null,"pause results cannot expose camp services remotely")
	session.open_camp()
	button(tr("camp.title")).pressed.emit()
	check(button(tr("camp.expedition"))!=null and button(tr("demo.results"))!=null,"ending returns to functional camp with repeatable results")
	session.hud.show_title()
	await settle()
	await capture("title-en")
	Settings.set_locale(locale,false)
	Audio.shutdown()
	await settle()
	print("DEMO COMPLETION RUNTIME checks=",checks," verified=",failures==0)
	get_tree().quit(0 if failures==0 else 1)
