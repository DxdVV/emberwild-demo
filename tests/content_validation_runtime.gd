extends Node

var checks: int = 0
var failed: int = 0

func _ready() -> void:
	if "--validator-exit-check" in OS.get_cmdline_user_args():
		# Exercise the real CLI scene's failure exit/report without editing disk assets.
		Database.abilities["ability.spark"].windup = NAN
		get_tree().change_scene_to_file.call_deferred("res://debug/ValidateContent.tscn")
		return
	preload("res://tests/content_validation_checks.gd").new().run(check)
	print("CONTENT VALIDATION CHECKS ",checks," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failed += 1
	print("CONTENT CHECK ",message," verified=",value)
