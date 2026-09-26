class_name CreatureInstance extends RefCounted

var persistent_id: String = ""
var species_id: String = ""
var level: int = 1
var xp: int = 0
var traits: Array = []
var abilities: Array = []
var held_item: Dictionary = {}
var cosmetic: int = 0
var health_ratio: float = 1.0
var history: Dictionary = {}
var combat: CombatState
var saved_combat: Dictionary = {}

func ensure_combat() -> CombatState:
	if combat == null:
		combat = CombatState.new()
		combat.configure(Database.species[species_id],Factions.Team.COMPANION,self)
		combat.restore(saved_combat)
		saved_combat.clear()
	return combat

func sync_health() -> void:
	if combat != null: health_ratio = combat.health.current/combat.health.maximum

func refresh_stats() -> void:
	if combat==null: return
	var definition: SpeciesData = Database.species[species_id]
	var ratio := combat.health.current/combat.health.maximum
	combat.stats.base = definition.base_stats.duplicate()
	combat.stats.base.merge(Database.rules.stat_defaults)
	combat.stats.level = level
	combat.apply_traits(definition.passives,traits)
	combat.types.clear()
	combat.types.append(str(definition.element))
	if not str(definition.secondary_type).is_empty(): combat.types.append(str(definition.secondary_type))
	combat.health.reset(combat.stats.value("health"),ratio)
	sync_health()

static func create(species: SpeciesData, rng: RandomNumberGenerator) -> CreatureInstance:
	var result := CreatureInstance.new()
	result.persistent_id = "%x-%x-%x" % [Time.get_unix_time_from_system(),rng.randi(),rng.randi()]
	result.species_id = str(species.id)
	result.abilities = species.abilities.duplicate()
	result.cosmetic = int(rng.randf() < 0.025)
	var pool: Array = species.trait_pool if not species.trait_pool.is_empty() else Database.rules.default_traits
	if not pool.is_empty(): result.traits = [pool[rng.randi_range(0,pool.size()-1)]]
	return result

func to_dict() -> Dictionary:
	sync_health()
	return {"id":persistent_id,"species":species_id,"level":level,"xp":xp,"traits":traits.duplicate(),"abilities":abilities.duplicate(),"held_item":held_item.duplicate(true),"cosmetic":cosmetic,"health_ratio":health_ratio,"history":history.duplicate(true),"combat":combat.to_dict() if combat != null else saved_combat.duplicate(true)}

static func from_dict(data: Dictionary) -> CreatureInstance:
	var result := CreatureInstance.new()
	result.persistent_id = str(data.get("id",""))
	result.species_id = str(data.get("species",""))
	result.level = clampi(int(data.get("level",1)),1,100)
	result.xp = maxi(0,int(data.get("xp",0)))
	result.traits = data.get("traits",[]).duplicate()
	result.abilities = data.get("abilities",[]).duplicate()
	result.held_item = data.get("held_item",{}).duplicate(true)
	result.cosmetic = int(data.get("cosmetic",0))
	result.health_ratio = clampf(float(data.get("health_ratio",1)),0,1)
	result.history = data.get("history",{}).duplicate(true)
	result.saved_combat = data.get("combat",{}).duplicate(true)
	if Database.species.has(result.species_id): Progression.normalize_loadout(result)
	return result
