extends Node

func _ready() -> void: run.call_deferred()

func run() -> void:
	var viewer = load("res://debug/ContentViewer.tscn").instantiate()
	add_child(viewer)
	viewer.show_species(Database.species["species.guardian"])
	var preview: AnimationPreview = viewer.preview.get_child(0)
	preview.clip = "windup"
	preview.playing = false
	preview.show_frame(1)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/viewer-guardian.png")
	preview.clip = "death"
	preview.show_frame(3)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/viewer-death.png")
	for direction in ["south","north"]:
		preview.direction = direction
		for clip in ["release","death"]:
			preview.clip = clip
			preview.show_frame(5 if clip=="death" else 0)
			assert(preview.sprite.texture.atlas==preview.definition.directional_texture)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://build/viewer-guardian-%s-%s.png"%[direction,clip])
	print("VIEWER guardian front/back impact and six-frame defeat verified")
	preview.direction = "east"
	preview.clip = "death"
	for mirrored in [false,true]:
		preview.mirrored = mirrored
		for pose in [2,5]:
			preview.show_frame(pose)
			assert(preview.definition.clips.death.size()==6 and preview.sprite.texture.atlas==preview.definition.supplemental_textures["side_defeat"])
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://build/viewer-guardian-side-defeat-%s-%d.png"%["left" if mirrored else "right",pose])
	print("VIEWER guardian six-frame side defeat and mirror verified")
	viewer.show_species(Database.species["species.cinder"])
	preview = viewer.preview.get_child(0)
	preview.playing = false
	preview.clip = "release"
	for direction in ["north","south"]:
		preview.direction = direction
		preview.show_frame(0)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/viewer-cinder-%s.png"%direction)
		assert(preview.sprite.texture.atlas==preview.definition.directional_texture)
	print("VIEWER directional release frames verified")
	for id in ["species.cinder","species.rill","species.briar","species.volt","species.solstice"]:
		viewer.show_species(Database.species[id])
		preview = viewer.preview.get_child(0)
		preview.playing = false
		preview.clip = "death"
		for direction in ["east","south","north"]:
			preview.direction = direction
			assert(preview.definition.clips[preview.definition.clip_id("death",direction)].size()==6)
			for pose in [2,5]:
				preview.show_frame(pose)
				assert(preview.sprite.texture.atlas==preview.definition.supplemental_textures["defeat"])
				var sequence: Array = preview.definition.clips[preview.definition.clip_id("death",direction)]
				var data: Dictionary = preview.definition.action_frames[sequence[pose]]
				var foot: float = preview.sprite.position.y+(data.anchor[1]-data.region[3]*.5)*preview.definition.scale_for(data,true)*.55
				assert(absf(foot-(preview.view.size.y-10))<=.5)
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("res://build/viewer-%s-defeat-%s-%d.png"%[id.trim_prefix("species."),direction,pose])
	print("VIEWER six-frame collapse for all five companions verified in all three directions")
	viewer.show_species(Database.species["species.solstice"])
	preview = viewer.preview.get_child(0)
	preview.playing = false
	for direction in ["east","south","north"]:
		preview.direction = direction
		preview.clip = "release"
		preview.show_frame(0)
		assert(preview.sprite.texture.atlas==preview.definition.action_texture)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/viewer-solstice-%s.png"%direction)
	print("VIEWER distinct evolved creature verified in all three directions")
	viewer.show_trainer()
	preview = viewer.preview.get_child(0)
	preview.playing = false
	preview.clip = "death"
	preview.direction = "north"
	preview.show_frame(5)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/viewer-hero-defeat.png")
	assert(preview.sprite.texture.atlas==preview.definition.action_texture)
	print("VIEWER hero defeat verified")
	for direction in ["south","east","north"]:
		for clip in ["windup","release","hurt","dodge"]:
			preview.direction = direction
			preview.clip = clip
			preview.show_frame(0)
			assert(preview.sprite.texture.atlas==(preview.definition.supplemental_textures["reactions"] if clip in ["hurt","dodge"] else preview.definition.directional_texture))
			if clip in ["hurt","dodge"]:
				assert(preview.definition.clips[preview.definition.clip_id(clip,direction)].size()==3)
				preview.show_frame(1)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			if clip=="release": get_viewport().get_texture().get_image().save_png("res://build/viewer-hero-combat-%s.png"%direction)
			if clip in ["hurt","dodge"]: get_viewport().get_texture().get_image().save_png("res://build/viewer-hero-%s-%s.png"%[clip,direction])
	print("VIEWER hero combat verified in all three directions")
	get_tree().quit()
