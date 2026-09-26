extends Node

class Probe extends Node2D:
	var batched := false
	var drops: Array = []
	var batch := LootMarkerBatch.new()
	func _draw() -> void:
		if batched:
			batch.update(drops)
			draw_multimesh(batch.instances,null)
		else:
			for drop in drops:
				var color: Color = LootMarkerBatch.COLORS[clampi(int(drop.item.rarity),0,3)]
				draw_line(drop.at,drop.at+Vector2(0,-30),Color(color,.5),2)
				draw_circle(drop.at,4,color)

var views: Array[SubViewport] = []
var probes: Array[Probe] = []
var comparisons: Array = []
var data_checks: int = 0
var data_failures: int = 0

func check(value: bool, label: String) -> void:
	data_checks += 1
	if not value: data_failures += 1
	print("LOOT MARKER DATA ",label," verified=",value)

func _ready() -> void: run.call_deferred()

func run() -> void:
	preload("res://tests/loot_marker_checks.gd").new().run(check)
	var drops: Array = []
	for index in 120:
		drops.append({"at":Vector2(50+index%20*42,index/20*55+70)+Vector2(.25,.5)*(index%4),"item":{"rarity":index%4}})
	# Coincident different rarities also exercise per-item alpha/painter ordering.
	drops.append({"at":Vector2(170,410),"item":{"rarity":0}})
	drops.append({"at":Vector2(171,409),"item":{"rarity":3}})
	for index in 2:
		var container := SubViewportContainer.new()
		container.position = Vector2(index*480,100)
		add_child(container)
		var view := SubViewport.new()
		view.size = Vector2i(480,270)
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		view.snap_2d_transforms_to_pixel = true
		view.transparent_bg = true
		container.add_child(view)
		views.append(view)
		var probe := Probe.new()
		probe.batched = index==1
		probe.drops = drops
		probe.scale = Vector2(.5,.5)
		view.add_child(probe)
		probes.append(probe)
	await compare("plain")
	for view in views:
		var ambient := CanvasModulate.new()
		ambient.color = Color(.5,.7,.6)
		view.add_child(ambient)
		var light := PointLight2D.new()
		var gradient := Gradient.new()
		gradient.set_color(0,Color.WHITE)
		gradient.set_color(1,Color.TRANSPARENT)
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(.5,.5)
		texture.fill_to = Vector2(1,.5)
		light.texture = texture
		light.texture_scale = 5
		light.position = Vector2(200,100)
		light.color = Color(1,.6,.3)
		view.add_child(light)
	await compare("lit")
	for probe in probes: probe.position = Vector2(-23.5,17.25)
	await compare("panned")
	var timing := []
	for enabled in [0,1]:
		probes[1-enabled].hide()
		probes[enabled].show()
		for frame in 3: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		timing.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var verified: bool = data_failures==0 and comparisons.all(func(entry): return entry.maximum_difference<=1 and entry.nonempty_channels>0) and timing[1]<timing[0]
	var result := {"data_checks":data_checks,"data_failures":data_failures,"comparisons":comparisons,"draw_calls":timing,"instances":probes[1].batch.instances.instance_count,"verified":verified}
	FileAccess.open("res://build/loot-markers-render.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("LOOT MARKERS RENDER ",JSON.stringify(result))
	Audio.shutdown()
	for frame in 4: await get_tree().process_frame
	get_tree().quit(0 if verified else 1)

func compare(label: String) -> void:
	for frame in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var before := views[0].get_texture().get_image()
	var after := views[1].get_texture().get_image()
	before.save_png("res://build/loot-markers-"+label+"-before.png")
	after.save_png("res://build/loot-markers-"+label+"-after.png")
	var left := before.get_data()
	var right := after.get_data()
	var changed := 0
	var maximum := 0
	var nonempty := 0
	for index in left.size():
		if left[index]>0: nonempty += 1
		var difference := absi(int(left[index])-int(right[index]))
		if difference>0: changed += 1
		maximum = maxi(maximum,difference)
	comparisons.append({"case":label,"changed_channels":changed,"maximum_difference":maximum,"nonempty_channels":nonempty})
