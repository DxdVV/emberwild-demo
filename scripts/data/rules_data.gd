class_name RulesData extends Resource

@export var type_chart: Dictionary = {}
@export var reactions: Array[Dictionary] = []
@export var elite_affixes: Array[Dictionary] = []
@export var item_affixes: Array[Dictionary] = []
@export var loot_tables: Dictionary = {}
@export var trainer_stats: Dictionary = {"health":180.0,"attack":7.0,"defense":8.0,"speed":160.0}
@export var boss_phases: Array[Dictionary] = []
@export var party_limit: int = 6
@export var active_limit: int = 2
@export var swap_cooldown: float = 3.0
@export var capture_range: float = 220.0
@export var capture_cooldown: float = 2.0
@export var xp_base: int = 60
@export var defense_factor: float = 0.035
@export var level_scaling: float = 0.14
@export var world_seed: int = 48371
@export var default_traits: Array[String] = ["enduring","resonant","steadfast","swift"]
@export var stat_defaults: Dictionary = {"critical_chance":.08,"energy_regeneration":13.0,"status_duration":0.0,"cooldown_reduction":0.0}
