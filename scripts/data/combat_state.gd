class_name CombatState extends RefCounted

# Owned by the individual/session, not by its temporary scene representation.
var identity: String = ""
var faction: int = Factions.Team.WILD
var types: Array = ["neutral"]
var stats := StatsComponent.new()
var health := HealthComponent.new()
var energy := EnergyComponent.new()
var cooldowns := CooldownComponent.new()
var statuses := StatusComponent.new()
var triggers := TriggerComponent.new()
var dodge_cooldown: float = 0
var damage_system: DamageSystem
var actor_ref: WeakRef
var ability_modifier_sources: Dictionary = {}
var trait_sources: Array[String] = []

func configure(data: SpeciesData, team: int, creature: CreatureInstance = null, affix: Dictionary = {}) -> void:
	faction = team
	stats.base = data.base_stats.duplicate() if data != null else Database.rules.trainer_stats.duplicate()
	stats.base.merge(Database.rules.stat_defaults)
	stats.level = creature.level if creature != null else 1
	stats.scaling = Database.rules.level_scaling
	types = [str(data.element)] if data != null else ["neutral"]
	if data != null and not str(data.secondary_type).is_empty(): types.append(str(data.secondary_type))
	if not affix.is_empty(): stats.set_source("elite",affix.get("modifiers",[]))
	triggers.set_source("elite",affix.get("triggers",[]))
	statuses.state_ref = weakref(self)
	apply_traits(data.passives if data != null else [],creature.traits if creature != null else [])
	if creature != null:
		identity = creature.persistent_id
		apply_held_item(creature.held_item)
	health.reset(stats.value("health"),creature.health_ratio if creature != null else 1.0)

func apply_held_item(item: Dictionary) -> void:
	stats.remove_source("held")
	triggers.set_source("held",[])
	ability_modifier_sources.erase("held")
	if item.is_empty(): return
	stats.set_source("held",ItemGenerator.modifiers(item))
	var definition: ItemData = Database.items.get(item.get("base",""))
	if definition != null:
		triggers.set_source("held",definition.triggers)
		ability_modifier_sources["held"] = definition.ability_mods.duplicate()

func apply_traits(passives: Array, individual_traits: Array) -> void:
	for key in trait_sources:
		stats.remove_source(key)
		triggers.set_source(key,[])
		ability_modifier_sources.erase(key)
	trait_sources.clear()
	for id in passives+individual_traits:
		var definition: TraitData = Database.traits.get(str(id))
		if definition==null: continue
		var key := "trait:"+str(id)
		if key in trait_sources: continue
		trait_sources.append(key)
		stats.set_source(key,definition.modifiers)
		triggers.set_source(key,definition.triggers)
		ability_modifier_sources[key] = definition.ability_mods.duplicate()

func ability_mods() -> Dictionary:
	return combine_ability_mods(ability_modifier_sources)

static func combine_ability_mods(sources: Dictionary) -> Dictionary:
	var result := {"projectiles":1,"chains":0}
	for modifiers in sources.values():
		result.projectiles += maxi(0,int(modifiers.get("projectiles",1))-1)
		result.chains += maxi(0,int(modifiers.get("chains",0)))
	result.projectiles = mini(5,result.projectiles)
	result.chains = mini(4,result.chains)
	return result

func bind(actor: Actor) -> void:
	actor_ref = weakref(actor)
	damage_system = actor.world.damage
	triggers.owner_actor = actor

func unbind(actor: Actor) -> void:
	if actor_ref != null and actor_ref.get_ref()==actor:
		actor_ref = null
		triggers.owner_actor = null

func tick(delta: float) -> void:
	health.tick(delta)
	cooldowns.tick(delta)
	triggers.tick(delta)
	dodge_cooldown = maxf(0,dodge_cooldown-delta)
	if health.current>0:
		energy.regeneration = stats.value("energy_regeneration")
		energy.tick(delta)
	statuses.tick(delta)

func rest() -> void:
	statuses.clear()
	health.reset(stats.value("health"))
	health.shield = 0
	health.invulnerable = 0
	energy.current = energy.maximum
	cooldowns.reset()
	triggers.cooldowns.clear()
	dodge_cooldown = 0

func to_dict() -> Dictionary:
	return {"health_ratio":health.current/health.maximum,"shield":health.shield,"invulnerable":health.invulnerable,"energy":energy.current,"cooldowns":cooldowns.to_dict(),"statuses":statuses.to_array(),"triggers":triggers.cooldowns.duplicate(),"dodge_cooldown":dodge_cooldown}

func restore(data: Dictionary) -> void:
	if data.is_empty(): return
	statuses.restore(data.get("statuses",[]))
	health.reset(stats.value("health"),clampf(float(data.get("health_ratio",1)),0,1))
	health.shield = clampf(float(data.get("shield",0)),0,health.maximum)
	health.invulnerable = clampf(float(data.get("invulnerable",0)),0,60)
	energy.current = clampf(float(data.get("energy",energy.maximum)),0,energy.maximum)
	dodge_cooldown = clampf(float(data.get("dodge_cooldown",0)),0,60)
	cooldowns.restore(data.get("cooldowns",{}))
	triggers.cooldowns.clear()
	for key in data.get("triggers",{}): triggers.cooldowns[str(key)] = float(data.triggers[key])
