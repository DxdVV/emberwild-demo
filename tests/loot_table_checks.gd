extends RefCounted

func run(check: Callable) -> void:
	var generator := ItemGenerator.new()
	generator.rng.seed = 929
	var sequence: Array[Dictionary] = []
	var seen: Dictionary = {}
	var dropped := 0
	var ordinary_only := true
	var elite_guaranteed := true
	for index in 1200:
		var item := generator.generate_drop("common" if index%2==0 else "elite",3)
		sequence.append(item)
		if index%2==1 and item.is_empty(): elite_guaranteed = false
		if item.is_empty(): continue
		dropped += 1
		seen[item.base] = true
		ordinary_only = ordinary_only and item.base!="item.relic" and item.level==3
	check.call(ordinary_only and seen.size()==6,"ordinary and elite loot include all six allowed bases and never the boss relic")
	check.call(elite_guaranteed and dropped>600 and dropped<1200,"elite drops are guaranteed while ordinary chance still permits no item")
	var registry: Dictionary = Database.items
	var keys := registry.keys()
	keys.reverse()
	Database.items = {}
	for id in keys: Database.items[id] = registry[id]
	generator.rng.seed = 929
	var repeated: Array[Dictionary] = []
	for index in 1200: repeated.append(generator.generate_drop("common" if index%2==0 else "elite",3))
	check.call(sequence==repeated,"seeded drops are independent of Resource registry enumeration order")
	Database.items = registry
	var unique := true
	for index in 100:
		var item := generator.generate_drop("boss",3)
		unique = unique and item.get("base")=="item.relic" and item.get("rarity")==3 and item.get("level")==5
	check.call(unique,"boss table guarantees its explicit level-five unique reward")
	var state := generator.rng.state
	check.call(generator.generate_drop("missing",1).is_empty() and generator.rng.state==state,"unknown loot source cannot generate an item or advance RNG")
	var tables := Database.rules.loot_tables.duplicate(true)
	Database.rules.loot_tables.common.chance = 0.0
	check.call(generator.generate_drop("common",1).is_empty() and generator.rng.state==state,"zero drop chance is respected without an unnecessary random draw")
	for mutation in [{"chance":1.2},{"chance":NAN},{"entries":[]},{"entries":[{"item":"missing","weight":1}]},{"entries":[{"item":"item.seed","weight":0}]},{"entries":[{"item":"item.seed","weight":INF}]},{"entries":[{"item":"item.seed","weight":1,"level":0}]},{"entries":[{"item":"item.seed","weight":1,"rarity":4}]},{"entries":[{"item":"item.seed","weight":1},{"item":"item.seed","weight":1}]}]:
		Database.rules.loot_tables = tables.duplicate(true)
		Database.rules.loot_tables.common.merge(mutation,true)
		check.call(not ContentValidator.loot_tables(Database).is_empty(),"invalid loot-table content is rejected: "+str(mutation))
	Database.rules.loot_tables = tables
	check.call(ContentValidator.loot_tables(Database).is_empty(),"authored loot tables validate after rejected mutations")
