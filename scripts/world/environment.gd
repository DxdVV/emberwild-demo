class_name WorldEnvironment2D extends Node2D

var world
var obstacles: Array[Rect2] = []
var motes: GPUParticles2D

func _ready() -> void:
	y_sort_enabled = true
	var area: AreaData = world.area
	for entry in area.layout.props:
		prop(int(entry.cell),AreaLayout.point(entry.at),float(entry.height),bool(entry.get("solid",false)))
	for entry in area.layout.lights:
		light(AreaLayout.point(entry.at),Color(entry.color),float(entry.energy),float(entry.radius))
	var ambient := CanvasModulate.new()
	ambient.color = area.tint
	add_child(ambient)
	add_motes()
	Settings.changed.connect(update_quality)

func prop(cell: int, at: Vector2, height: float, solid: bool) -> void:
	var object := Node2D.new()
	object.position = at
	add_child(object)
	var sprite := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/environments/forest-pixel.png")
	atlas.region = Rect2((cell%3)*512,(cell/3)*512,512,512)
	sprite.texture = atlas
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.material = preload("res://shaders/sprite_pixels.tres")
	sprite.scale = Vector2.ONE*height/480
	sprite.position.y = -height*.42
	object.add_child(sprite)
	if solid:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(height*.23,22)
		shape.shape = rectangle
		body.add_child(shape)
		object.add_child(body)
		obstacles.append(Rect2(at-rectangle.size*.5,rectangle.size))

func light(at: Vector2, color: Color, energy: float, radius: float) -> void:
	var node := PointLight2D.new()
	var gradient := Gradient.new()
	gradient.set_color(0,Color.WHITE)
	gradient.set_color(1,Color.TRANSPARENT)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(.5,.5)
	texture.fill_to = Vector2(1,.5)
	node.texture = texture
	node.texture_scale = radius/128
	node.position = at
	node.color = color
	node.energy = energy
	add_child(node)

func add_motes() -> void:
	motes = GPUParticles2D.new()
	motes.position = world.area.size*.5
	motes.amount = 100
	motes.lifetime = 8
	motes.preprocess = 8
	motes.visibility_rect = Rect2(-world.area.size*.5,world.area.size)
	motes.z_index = 25
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(world.area.size.x*.5,world.area.size.y*.5,0)
	material.direction = Vector3(1,-1,0)
	material.spread = 30
	material.gravity = Vector3.ZERO
	material.initial_velocity_min = 6
	material.initial_velocity_max = 14
	material.scale_min = 1
	material.scale_max = 2
	material.color = Color("bfc780")
	motes.process_material = material
	add_child(motes)
	update_quality()

func update_quality() -> void:
	if is_instance_valid(motes): motes.amount_ratio = [0.2,0.5,1.0][clampi(Settings.effects_quality,0,2)]
