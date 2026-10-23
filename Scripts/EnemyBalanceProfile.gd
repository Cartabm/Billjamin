
extends Resource
class_name EnemyBalanceProfile

@export_group("Spawn Settings")
@export var spawn_interval: float = 1.5
@export var minimum_spawn_interval: float = 0.75
@export var spawn_interval_decrease: float = 0.25
@export var difficulty_interval: float = 30.0

@export var horde_size: int = 4
@export var horde_size_increase: int = 1
@export var horde_increase_interval: float = 60.0
@export var max_living_enemies: int = 100

@export_group("Enemy Spawn Weights")
@export_range(0, 100) var regular_weight: int = 50
@export_range(0, 100) var charger_weight: int = 20
@export_range(0, 100) var stalker_weight: int = 15
@export_range(0, 100) var brute_weight: int = 10
@export_range(0, 100) var ranged_weight: int = 5

@export_group("Enemy Difficulty")
@export var health_multiplier: float = 1.0
@export var damage_multiplier: float = 1.0
@export var speed_multiplier: float = 1.0
@export_range(0.0, 1.0, 0.01) var elite_chance: float = 0.08

@export_group("Gold Rewards")
@export_range(0.0, 1.0, 0.01) var gold_drop_chance: float = 0.25
@export var gold_minimum: int = 5
@export var gold_maximum: int = 15

@export_range(0.0, 1.0, 0.01) var elite_gold_drop_chance: float = 0.75
@export var elite_gold_minimum: int = 15
@export var elite_gold_maximum: int = 35

@export_group("Dungeon Encounters")
@export var dungeon_kills_required: int = 30
@export var dungeon_max_alive: int = 12
@export var dungeon_initial_spawn: int = 6
@export var dungeon_enemies_per_tick: int = 2
@export var dungeon_spawn_interval: float = 0.8

@export var dungeon_health_increase_per_room: float = 0.15
@export var dungeon_damage_increase_per_room: float = 0.0575
@export var dungeon_enemy_count_increase_per_room: float = 0.10
@export var dungeon_extra_alive_every_rooms: int = 3
@export var dungeon_spawn_speed_increase_per_room: float = 0.05
@export var dungeon_minimum_spawn_interval: float = 0.15

@export_group("Arena")
@export var arena_duration: float = 600.0
