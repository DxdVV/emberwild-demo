extends Control

var preview: Control
var current_cell: int = 0
var current_background: Color = Color("24392d")
var stage: ColorRect

func _ready() -> void:
	theme = UIStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage = ColorRect.new()
	stage.color = current_background
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(stage)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,28)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",30)
	margin.add_child(row)
	var navigation_scroll := ScrollContainer.new()
	navigation_scroll.custom_minimum_size.x = 275
	navigation_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	navigation_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(navigation_scroll)
	var controls := VBoxContainer.new()
	controls.custom_minimum_size.x = 250
	navigation_scroll.add_child(controls)
	controls.add_child(UIStyle.label("ПРОСМОТР КОНТЕНТА",22,UIStyle.GOLD))
	controls.add_child(UIStyle.button("Проверить данные",show_validation))
	controls.add_child(UIStyle.button("Хранительница",show_trainer))
	for species: SpeciesData in Database.species.values():
		controls.add_child(UIStyle.button(tr(species.name_key),func(): show_species(species)))
	for cell in 6: controls.add_child(UIStyle.button("Окружение · "+str(cell+1),func(): show_environment(cell)))
	controls.add_child(UIStyle.button("Сменить освещение",func(): stage.color = Color("584b34") if stage.color==current_background else current_background))
	controls.add_child(UIStyle.button("Играть",func(): get_tree().change_scene_to_file("res://scenes/main.tscn")))
	var preview_scroll := ScrollContainer.new()
	preview_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(preview_scroll)
	preview = VBoxContainer.new()
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_scroll.add_child(preview)
	if Database.errors.is_empty(): show_species(Database.species["species.cinder"])
	else: show_validation()

func show_validation() -> void:
	clear_preview()
	var problems: PackedStringArray = Database.validate()
	preview.add_child(UIStyle.label("ПРОВЕРКА ДАННЫХ",22,UIStyle.GOLD))
	preview.add_child(UIStyle.label("Ошибок: "+str(problems.size()),18,UIStyle.GREEN if problems.is_empty() else Color("ef997e")))
	PartyDetails.wrapped(preview,"Проверяются загруженные Resources. Для проверки файлов после редактирования запустите tools/validate-content.ps1.")
	for kind in ContentFields.KINDS: preview.add_child(UIStyle.label(kind+": "+str(Database.get(kind).size()),14))
	for problem in problems: PartyDetails.wrapped(preview,problem,Color("ef997e"))

func clear_preview() -> void:
	for child in preview.get_children():
		preview.remove_child(child)
		child.queue_free()

func show_species(species: SpeciesData) -> void:
	clear_preview()
	if Database.animations.has(str(species.animation_id)):
		var animation := AnimationPreview.new()
		animation.definition = Database.animations[str(species.animation_id)]
		preview.add_child(animation)
	else: preview.add_child(UIStyle.species_portrait(species,256))
	preview.add_child(UIStyle.label(tr(species.name_key),24,species.color))
	preview.add_child(UIStyle.label(str(species.id)+" · "+str(species.element),14,UIStyle.MUTED))
	for id in species.abilities:
		var ability: AbilityData = Database.abilities[id]
		preview.add_child(UIStyle.label("%s · сила %.1f · откат %.1fs" % [tr(ability.name_key),ability.power,ability.cooldown],14))

func show_trainer() -> void:
	clear_preview()
	var animation := AnimationPreview.new()
	animation.definition = Database.animations["animation.ranger"]
	preview.add_child(animation)
	preview.add_child(UIStyle.label("Хранительница",24,UIStyle.GOLD))
	preview.add_child(UIStyle.label("Ходьба, атака, попадание, рывок и падение · три направления",14,UIStyle.MUTED))

func show_environment(cell: int) -> void:
	clear_preview()
	var image := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/environments/forest-pixel.png")
	atlas.region = Rect2((cell%3)*512,(cell/3)*512,512,512)
	image.texture = atlas
	image.custom_minimum_size = Vector2(380,380)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.add_child(image)
