class_name UIStyle extends RefCounted

const INK := Color("0e211f")
const PAPER := Color("ede3c9")
const MUTED := Color("98afa1")
const GOLD := Color("d4ad6d")
const GREEN := Color("91d4b6")

static func box(background: Color = INK, border: Color = Color("52604b"), width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(4)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

static func theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 14
	result.set_color("font_color","Label",PAPER)
	result.set_color("font_color","Button",PAPER)
	result.set_color("font_hover_color","Button",Color("fff0c9"))
	result.set_stylebox("normal","Button",box(Color("1b3630"),Color("62745a")))
	result.set_stylebox("hover","Button",box(Color("315447"),GOLD))
	result.set_stylebox("pressed","Button",box(Color("45604a"),GOLD))
	result.set_stylebox("focus","Button",box(Color(0,0,0,0),GOLD,2))
	result.set_stylebox("panel","PanelContainer",box())
	return result

static func label(text: String, font_size: int = 14, color: Color = PAPER) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	return node

static func button(text: String, callback: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.pressed.connect(func(): Audio.play("ui"); callback.call())
	return node

static func species_portrait(species: SpeciesData, height: int = 64) -> TextureRect:
	var image := portrait(species.sprite_cell,height)
	if species.portrait != null: image.texture = species.portrait
	return image

static func portrait(cell: int, height: int = 64) -> TextureRect:
	var image := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/characters/creatures-pixel.png")
	atlas.region = Rect2((cell%3)*512,(cell/3)*512,512,512)
	image.texture = atlas
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.custom_minimum_size = Vector2(height,height)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return image
