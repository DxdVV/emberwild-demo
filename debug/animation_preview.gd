class_name AnimationPreview extends VBoxContainer

var definition: SpriteAnimationData
var sprite: Sprite2D
var view: SubViewport
var clip: String = "walk"
var direction: String = "east"
var clock_time: float = 0
var playing: bool = true
var mirrored: bool = false
var label: Label
var slider: HSlider
var ground: Line2D
var current_step: int = 0
var frame_textures: Array[AtlasTexture] = []
var action_textures: Array[AtlasTexture] = []

func _ready() -> void:
	for pair in [[definition.frames,false,frame_textures],[definition.action_frames,true,action_textures]]:
		for frame in pair[0]:
			var texture := AtlasTexture.new()
			texture.atlas = definition.texture_for(frame,pair[1])
			texture.region = Rect2(frame.region[0],frame.region[1],frame.region[2],frame.region[3])
			pair[2].append(texture)
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(480,270)
	container.stretch = true
	container.stretch_shrink = 2
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(container)
	view = SubViewport.new()
	view.size = Vector2i(240,135)
	view.disable_3d = true
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	container.add_child(view)
	ground = Line2D.new()
	ground.points = PackedVector2Array([Vector2(20,125),Vector2(220,125)])
	ground.width = 1
	ground.default_color = Color("658570")
	view.add_child(ground)
	sprite = Sprite2D.new()
	sprite.material = preload("res://shaders/sprite_pixels.tres")
	view.add_child(sprite)
	var buttons := HFlowContainer.new()
	add_child(buttons)
	var names := {"walk":"Ходьба","windup":"Подготовка","release":"Удар","hurt":"Попадание","dodge":"Рывок","death":"Падение"}
	for id in names:
		if id=="walk" or definition.clips.has(id): buttons.add_child(UIStyle.button(names[id],func(): clip=id; clock_time=0; playing=true))
	var options := HFlowContainer.new()
	add_child(options)
	options.add_child(UIStyle.button("Пуск / пауза",func(): playing=not playing))
	options.add_child(UIStyle.button("Зеркало",func(): mirrored=not mirrored))
	for id in definition.directions:
		options.add_child(UIStyle.button({"east":"Вбок","north":"Со спины","south":"Спереди"}.get(id,id),func(): direction=id; clock_time=0))
	slider = HSlider.new()
	slider.step = 1
	slider.value_changed.connect(func(value):
		playing=false
		clock_time=value/8.0
		show_frame(int(value)))
	add_child(slider)
	label = UIStyle.label("",12,UIStyle.MUTED)
	add_child(label)
	show_frame(0)

func _process(delta: float) -> void:
	if playing:
		clock_time += delta
		show_frame(int(clock_time*8))
	else: show_frame(current_step)

func show_frame(step: int) -> void:
	current_step = step
	var clip_id := definition.clip_id(clip,direction)
	var action := definition.clips.has(clip_id)
	var sequence: Array = definition.clips[clip_id] if action else definition.directions.get(direction,range(definition.frames.size()))
	var index := int(sequence[step%sequence.size()])
	var data: Dictionary = definition.action_frames[index] if action else definition.frames[index]
	var scale_value := definition.scale_for(data,action)*.55
	sprite.texture = action_textures[index] if action else frame_textures[index]
	sprite.scale = Vector2.ONE*scale_value
	sprite.flip_h = mirrored
	var offset := Vector2(data.region[2]*.5-data.anchor[0],data.region[3]*.5-data.anchor[1])*scale_value
	if mirrored: offset.x=-offset.x
	var center := Vector2(roundf(view.size.x*.5),view.size.y-10)
	var phase := float(step%sequence.size())/sequence.size()
	sprite.position = center+offset.round()+Vector2(0,roundf(definition.vertical_offset(clip,phase)*.55))
	ground.points = PackedVector2Array([center+Vector2(-100,0),center+Vector2(100,0)])
	slider.max_value = sequence.size()-1
	slider.set_value_no_signal(step%sequence.size())
	label.text = "%s · кадр %d / %d · nearest, целая пиксельная сетка"%[clip,step%sequence.size()+1,sequence.size()]
