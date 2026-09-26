class_name LootMarkerBatch extends RefCounted

const COLORS := [Color("ccc9b0"),Color("8cb9e9"),Color("eac577"),Color("e5a966")]
var instances := MultiMesh.new()

func _init() -> void:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	# Keep beam and coin in the original per-item painter order.
	for point in [Vector2(-1,-30),Vector2(1,-30),Vector2(1,0),Vector2(-1,-30),Vector2(1,0),Vector2(-1,0)]:
		vertices.append(Vector3(point.x,point.y,0))
		colors.append(Color(1,1,1,.5))
	for segment in 16:
		for point in [Vector2.ZERO,Vector2.from_angle(segment*TAU/16)*4,Vector2.from_angle((segment+1)*TAU/16)*4]:
			vertices.append(Vector3(point.x,point.y,0))
			colors.append(Color.WHITE)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	instances.transform_format = MultiMesh.TRANSFORM_2D
	instances.use_colors = true
	instances.mesh = mesh

func update(drops: Array) -> void:
	if instances.instance_count!=drops.size(): instances.instance_count = drops.size()
	for index in drops.size():
		var drop: Dictionary = drops[index]
		instances.set_instance_transform_2d(index,Transform2D(0,drop.at))
		instances.set_instance_color(index,COLORS[clampi(int(drop.item.rarity),0,3)])
