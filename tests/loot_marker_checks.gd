extends RefCounted

static func color_error(actual: Color, expected: Color) -> float:
	var maximum := 0.0
	for component in 4: maximum = maxf(maximum,absf(actual[component]-expected[component]))
	return maximum

func run(check: Callable) -> void:
	var batch := LootMarkerBatch.new()
	var drops: Array = []
	for index in 120: drops.append({"at":Vector2(index*3.25,index*.5),"item":{"id":str(index),"rarity":index%4}})
	var before := drops.duplicate(true)
	batch.update(drops)
	check.call(batch.instances.instance_count==120,"loot marker batch retains every visible drop")
	var native := DisplayServer.get_name()!="headless"
	var positions := true
	var maximum_color_error := 0.0
	for index in drops.size():
		positions = positions and batch.instances.get_instance_transform_2d(index).origin==drops[index].at
		maximum_color_error = maxf(maximum_color_error,color_error(batch.instances.get_instance_color(index),LootMarkerBatch.COLORS[index%4]))
	if native:
		check.call(positions,"native loot marker instances preserve ordered fractional world positions")
		print("LOOT MARKERS native color readback maximum error=",maximum_color_error)
		check.call(maximum_color_error<=1.0/255,"native loot marker instances preserve rarity colors within one display level")
	else:
		print("LOOT MARKERS dummy backend readback: position=",batch.instances.get_instance_transform_2d(1).origin," color=",batch.instances.get_instance_color(1),"; GPU values are checked natively")
	check.call(before==drops,"marker rendering cannot mutate item or drop state")
	var buffer := batch.instances
	var mesh := batch.instances.mesh
	drops[0].at = Vector2(-10,40)
	drops[0].item.rarity = 3
	batch.update(drops)
	check.call(batch.instances==buffer and batch.instances.mesh==mesh,"unchanged marker population reuses mesh and instance resources")
	if native: check.call(batch.instances.get_instance_transform_2d(0).origin==Vector2(-10,40) and color_error(batch.instances.get_instance_color(0),LootMarkerBatch.COLORS[3])<=1.0/255,"native marker reuse refreshes position and rarity")
	drops.remove_at(0)
	batch.update(drops)
	check.call(batch.instances.instance_count==119,"pickup shrinks the marker population")
	if native: check.call(batch.instances.get_instance_transform_2d(0).origin==drops[0].at,"native pickup removes the old marker and preserves the remaining order")
	batch.update([])
	check.call(batch.instances.instance_count==0,"empty or fully hidden loot clears all instances")
	batch.update(drops)
	check.call(batch.instances.instance_count==119 and batch.instances.mesh==mesh,"revealing loot repopulates the same marker mesh")
