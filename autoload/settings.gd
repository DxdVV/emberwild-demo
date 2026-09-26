extends Node

signal changed
const PATH := "user://settings.cfg"
const DEFAULT_VOLUMES := {"Master":0.8,"Music":0.4,"SFX":0.8,"UI":0.65,"Ambience":0.4,"Voice":0.8}
var storage_path: String = PATH
var effects_quality: int = 2
var shake: bool = true
var fullscreen: bool = false
var volumes: Dictionary = DEFAULT_VOLUMES.duplicate()
var locale: String = "ru"
var inputs := InputBindings.new()
var loot_filter := LootFilter.new()
var capturing_input: bool = false
var block_input_frames: int = -1

func input_blocked() -> bool:
	return capturing_input or Engine.get_process_frames()<=block_input_frames

func _ready() -> void: load_settings()

func set_locale(value: String, save: bool = true) -> Error:
	if value not in ["ru","en"]: return ERR_INVALID_PARAMETER
	locale = value
	apply_locale()
	if save: return persist()
	changed.emit()
	return OK

func apply_locale() -> void:
	TranslationServer.set_locale(locale)
	get_window().title = tr("app.title")

func load_settings() -> void:
	var config := ConfigFile.new()
	var loaded := config.load(storage_path)
	if loaded!=OK and FileAccess.file_exists(storage_path+".bak"):
		config = ConfigFile.new()
		config.load(storage_path+".bak")
	var quality = config.get_value("graphics","effects",2)
	effects_quality = int(quality) if CombatSaveSchema.integer(quality,0,2) else 2
	shake = config.get_value("graphics","shake",true)==true
	fullscreen = config.get_value("graphics","fullscreen",false)==true
	locale = str(config.get_value("general","locale","ru"))
	if locale not in ["ru","en"]: locale = "ru"
	volumes = DEFAULT_VOLUMES.duplicate()
	for bus in volumes:
		var value = config.get_value("audio",bus,volumes[bus])
		if CombatSaveSchema.number(value,0,1): volumes[bus] = float(value)
	inputs.restore(config.get_value("input","bindings",{}))
	loot_filter.restore(config.get_value("loot","filter",{}))
	apply_locale()
	if DisplayServer.get_name()!="headless": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	changed.emit()

func persist() -> Error:
	var config := ConfigFile.new()
	config.set_value("graphics","effects",effects_quality)
	config.set_value("graphics","shake",shake)
	config.set_value("graphics","fullscreen",fullscreen)
	config.set_value("general","locale",locale)
	config.set_value("input","bindings",inputs.bindings)
	config.set_value("loot","filter",loot_filter.to_dict())
	for bus in volumes: config.set_value("audio",bus,volumes[bus])
	var error := config.save(storage_path+".tmp")
	if error==OK and FileAccess.file_exists(storage_path): error = DirAccess.copy_absolute(storage_path,storage_path+".bak")
	if error==OK: error = DirAccess.rename_absolute(storage_path+".tmp",storage_path)
	changed.emit()
	return error
