class_name WorldTerrain extends Node2D

var area: AreaData
var seed_value: int = 0

func _ready() -> void:
	z_index = -20
	var ground := Polygon2D.new()
	ground.polygon = PackedVector2Array([Vector2.ZERO,Vector2(area.size.x,0),area.size,Vector2(0,area.size.y)])
	ground.uv = PackedVector2Array([Vector2.ZERO,Vector2(1,0),Vector2.ONE,Vector2(0,1)])
	var texture := PlaceholderTexture2D.new()
	texture.size = Vector2.ONE
	ground.texture = texture
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/forest_floor.gdshader")
	material.set_shader_parameter("ground_atlas",load("res://assets/environments/ground-coarse.png"))
	material.set_shader_parameter("world_size",area.size)
	var roads: Array[Vector4] = []
	var widths := PackedFloat32Array()
	for segment in area.layout.segments():
		roads.append(Vector4(segment.from.x,segment.from.y,segment.to.x,segment.to.y))
		widths.append(segment.width*.5)
	material.set_shader_parameter("trail_count",roads.size())
	roads.resize(32)
	widths.resize(32)
	material.set_shader_parameter("trails",roads)
	material.set_shader_parameter("trail_widths",widths)
	var clearings: Array[Vector4] = []
	var surfaces := PackedInt32Array()
	for clearing in area.layout.clearings:
		clearings.append(Vector4(clearing.at[0],clearing.at[1],clearing.radii[0],clearing.radii[1]))
		surfaces.append(1 if clearing.surface=="stone" else 0)
	material.set_shader_parameter("clearing_count",clearings.size())
	clearings.resize(12)
	surfaces.resize(12)
	material.set_shader_parameter("clearings",clearings)
	material.set_shader_parameter("surfaces",surfaces)
	ground.material = material
	add_child(ground)
