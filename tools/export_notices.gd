extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1:
		push_error("Expected one output path for bundled-engine notices")
		quit(1)
		return
	var content: String = "Godot Engine "+str(Engine.get_version_info().string)+"\n\n"
	content += Engine.get_license_text()+"\n\nTHIRD-PARTY COPYRIGHT NOTICES\n\n"
	for component in Engine.get_copyright_info():
		content += str(component.name)+"\n"
		for part in component.parts:
			for copyright_line in part.copyright: content += str(copyright_line)+"\n"
			content += "License: "+str(part.license)+"\n"
			for file in part.files: content += "  "+str(file)+"\n"
		content += "\n"
	content += "\nTHIRD-PARTY LICENSE TEXTS\n\n"
	var licenses := Engine.get_license_info()
	var names := licenses.keys()
	names.sort()
	for name in names: content += str(name)+"\n"+str(licenses[name])+"\n\n"
	var output := FileAccess.open(args[0],FileAccess.WRITE)
	if output==null:
		push_error("Cannot write engine notices: "+args[0])
		quit(1)
		return
	output.store_string(content)
	output.close()
	print("ENGINE NOTICES exported=true")
	quit()
