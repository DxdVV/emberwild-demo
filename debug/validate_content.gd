extends Node

func _ready() -> void:
	var errors: PackedStringArray = Database.validate()
	var counts := {}
	var total := 1 # RulesData has no registry ID.
	for kind in ContentFields.KINDS:
		counts[kind] = Database.get(kind).size()
		total += int(counts[kind])
	counts["rules"] = 1 if Database.rules!=null else 0
	var report := {"format":1,"valid":errors.is_empty(),"resources":counts,"errors":Array(errors),"engine":Engine.get_version_info().string}
	DirAccess.make_dir_recursive_absolute("res://build")
	var file := FileAccess.open("res://build/content-validation.json",FileAccess.WRITE)
	if file==null:
		push_error("Cannot write res://build/content-validation.json")
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	for problem in errors: print(problem)
	print("CONTENT VALIDATION valid=",errors.is_empty()," resources=",total," errors=",errors.size())
	get_tree().quit(0 if errors.is_empty() else 1)
