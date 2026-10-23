extends Resource
class_name CharacterBalance
## Starting stats and behavior for any player character.
## Each player scene uses its own .tres instance. Upgrades change runtime
## player values, not this shared resource.

enum CombatStyle { MELEE, PROJECTILE }
enum FacingMode { MOVEMENT, ATTACK_TARGET }

@export_group("Character Identity")
@export var character_label: String = "New Character"
@export var combat_style: CombatStyle = CombatStyle.PROJECTILE
@export var facing_mode: FacingMode = FacingMode.MOVEMENT

@export_group("Movement / Survival")
@export_range(0.1, 30.0, 0.1) var move_speed: float = 6.0
@export_range(0.0, 120.0, 0.5) var acceleration: float = 30.0
@export_range(0.1, 30.0, 0.1) var turn_speed: float = 10.0
@export_range(0.0, 50.0, 0.5) var gravity: float = 20.0
@export_range(1, 1000, 1) var max_health: int = 100
@export_range(0.0, 3.0, 0.05) var contact_damage_cooldown: float = 0.2

@export_group("Dodge")
@export_range(1.0, 40.0, 0.5) var dodge_speed: float = 16.0
@export_range(0.05, 2.0, 0.05) var dodge_duration: float = 0.5
@export_range(1.0, 500.0, 1.0) var max_dodge_energy: float = 100.0
@export_range(0.0, 500.0, 1.0) var dodge_energy_cost: float = 50.0
@export_range(0.0, 100.0, 0.5) var dodge_energy_regen: float = 10.0
@export var dodge_visual_spin: bool = false

@export_group("Basic Attack")
@export_range(1, 500, 1) var starting_damage: int = 10
@export_range(0.05, 3.0, 0.01) var attack_interval: float = 0.40
@export_range(0.5, 50.0, 0.5) var attack_range: float = 15.0
@export var auto_attack_enabled: bool = true
@export var manual_attack_enabled: bool = true
@export_range(0.1, 6.0, 0.05) var attack_animation_speed: float = 1.0
@export_range(0.0, 1.0, 0.01) var critical_hit_chance: float = 0.05
@export_range(1.0, 6.0, 0.1) var critical_damage_multiplier: float = 2.0
@export_range(0.0, 2.0, 0.01) var minimum_damage_multiplier: float = 0.80
@export_range(0.0, 3.0, 0.01) var maximum_damage_multiplier: float = 1.20

@export_group("Melee Attack")
@export_range(0.0, 2.0, 0.01) var melee_windup: float = 0.25
@export_range(1.0, 360.0, 1.0) var melee_attack_angle: float = 90.0
@export var follow_target_during_windup: bool = true

@export_group("Projectile Attack")
@export_range(0.0, 3.0, 0.05) var projectile_height: float = 0.5
@export_range(0.0, 90.0, 0.5) var multishot_spread_degrees: float = 10.0

@export_group("Starting Progression")
@export_range(1, 100, 1) var xp_to_level: int = 5
@export_range(1.0, 10.0, 0.1) var xp_multiplier: float = 1.0

@export_group("Ability Defaults: Blade Flurry")
@export_range(1, 100, 1) var blade_flurry_damage: int = 6
@export_range(0.1, 30.0, 0.1) var blade_flurry_radius: float = 3.0
@export_range(0.1, 60.0, 0.1) var blade_flurry_cooldown: float = 6.0
@export_range(0, 50, 1) var blade_flurry_damage_per_milestone: int = 2

@export_group("Death / Run")
@export var submit_leaderboard_on_death: bool = false

@export_group("Animation Names")
@export var idle_animation: StringName = &"Idle"
@export var run_animation: StringName = &"Run"
@export var attack_animation: StringName = &"Attack"
@export var hurt_animation: StringName = &"Hurt"
@export var death_animation: StringName = &"Death"
