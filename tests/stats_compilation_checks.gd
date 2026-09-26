extends RefCounted

func run(check: Callable) -> void:
	var stats := StatsComponent.new()
	stats.base = {"attack":100.0,"speed":90.0}
	stats.level = 3
	stats.scaling = .1
	var gear := [{"stat":"attack","value":10},{"stat":"attack","op":"add","value":.2}]
	stats.set_source("gear",gear)
	stats.set_source("buff",[{"stat":"attack","op":"multiply","value":1.5},{"stat":"speed","op":"multiply","value":.5}])
	check.call(is_equal_approx(stats.value("attack"),234) and stats.value("speed")==45,"compiled modifiers preserve level/flat/add/multiply order across stats")
	gear[0].value = 999
	check.call(is_equal_approx(stats.value("attack"),234),"modifier source owns a deep copy of caller data")
	stats.base.attack = 200
	check.call(is_equal_approx(stats.value("attack"),450),"direct base-stat edits remain live after modifier compilation")
	stats.level = 4
	stats.scaling = .2
	check.call(is_equal_approx(stats.value("attack"),594),"level and scaling changes do not retain stale compiled values")
	stats.set_source("gear",[{"stat":"attack","value":-20}])
	check.call(is_equal_approx(stats.value("attack"),450),"replacing a source removes all of its previous additive terms")
	stats.set_source("first_override",[{"stat":"attack","op":"override","value":7}])
	stats.set_source("last_override",[{"stat":"attack","op":"override","value":0}])
	stats.set_source("first_override",[{"stat":"attack","op":"override","value":11}])
	check.call(stats.value("attack")==0,"source replacement preserves override priority and a zero override")
	stats.remove_source("last_override")
	check.call(stats.value("attack")==11,"removing the last override exposes the previous source")
	stats.remove_source("first_override")
	stats.set_source("buff",[])
	check.call(is_equal_approx(stats.value("attack"),300) and stats.value("speed")==90,"empty source clears its multiplier without altering other sources")
	stats.remove_source("gear")
	stats.remove_source("missing")
	check.call(is_equal_approx(stats.value("attack"),320) and stats.value("absent")==0,"removing all sources restores current base and unknown stats remain zero")
