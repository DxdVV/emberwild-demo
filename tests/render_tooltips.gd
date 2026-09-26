extends Node

var session
var failed: bool = false
var helpers := preload("res://tests/localization_checks.gd").new()

func _ready() -> void: run.call_deferred()

func verify(value: bool, message: String) -> void:
	print("CONTEXT TOOLTIP ",message," verified=",value)
	if not value: failed = true

func settle(amount: int = 32) -> void:
	for index in amount: await get_tree().process_frame

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/context-tooltip-"+label+".png")

func point(control: Control) -> void:
	var event := InputEventMouseMotion.new()
	event.position = control.get_global_rect().get_center()
	get_viewport().warp_mouse(event.position)
	get_viewport().push_input(event,true)
	await settle()

func run() -> void:
	get_viewport().gui_embed_subwindows = true
	session = load("res://scenes/main.tscn").instantiate()
	add_child(session)
	session.autosave_remaining = 100000
	var hud: GameHUD = session.hud
	var tooltip := hud.context_tooltip
	hud.close_panel(true)
	get_tree().paused = true
	await settle(6)
	await point(hud.skill_labels[0])
	verify(tooltip.visible and tooltip.description.text==hud.skill_tooltip(0),"mouse hover opens current HUD ability")
	await capture("ability")
	var previous := tooltip.description.text
	session.party.swap_remaining = 0
	session.party.swap(2,0)
	await settle()
	verify(tooltip.visible and tooltip.description.text!=previous and tooltip.description.text==hud.skill_tooltip(0),"stationary mouse follows a real active-slot swap")
	await capture("swapped")
	hud.show_party()
	await settle(6)
	helpers.key(get_viewport(),KEY_TAB)
	await settle()
	verify(get_viewport().gui_get_focus_owner() is TextureRect and tooltip.visible,"Tab opens a creature portrait description")
	verify(tooltip.description.text==TooltipPresenter.creature_text(session.party.roster[0]),"focused portrait describes the correct roster member")
	await capture("creature")
	hud.show_inventory()
	await settle(6)
	helpers.key(get_viewport(),KEY_TAB)
	await settle()
	verify(tooltip.visible and tooltip.description.text==TooltipPresenter.item_summary(session.inventory.items[0]),"Tab opens item description on compare action")
	verify(Rect2(Vector2(8,8),hud.root.size-Vector2(16,16)).encloses(tooltip.get_global_rect()),"inventory tooltip fits the viewport")
	await capture("item")
	var position_before: Vector2 = session.world.trainer.position
	helpers.key(get_viewport(),KEY_ENTER)
	await settle(6)
	verify(hud.panel.visible and get_tree().paused and session.world.trainer.position==position_before and not tooltip.visible,"Enter still opens comparison without resuming combat")
	var previous_locale: String = Settings.locale
	Settings.set_locale("en",false)
	hud.show_inventory()
	await settle(6)
	helpers.key(get_viewport(),KEY_TAB)
	await settle()
	verify(tooltip.visible and tooltip.description.text==TooltipPresenter.item_summary(session.inventory.items[0]),"English tooltip is rebuilt from current item data")
	await capture("item-en")
	Settings.set_locale(previous_locale,false)
	await settle(6)
	hud.close_panel(true)
	get_tree().paused = true
	var edge := UIStyle.button("?",func(): pass)
	edge.position = Vector2(900,495)
	edge.size = Vector2(40,32)
	ContextTooltip.bind(edge,func(): return TooltipPresenter.creature_text(session.party.roster[0]))
	hud.root.add_child(edge)
	await point(edge)
	verify(tooltip.visible and Rect2(Vector2(8,8),hud.root.size-Vector2(16,16)).encloses(tooltip.get_global_rect()),"native bottom-right hover remains in bounds")
	await capture("edge")
	edge.queue_free()
	await settle()
	verify(not tooltip.visible,"removing hovered control closes tooltip")
	Audio.shutdown()
	await settle(5)
	print("CONTEXT TOOLTIP RENDER COMPLETE verified=",not failed)
	get_tree().quit(1 if failed else 0)
