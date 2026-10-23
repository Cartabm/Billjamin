extends CharacterBody3D
## Shared health, dodge energy, leveling, HUD, upgrades and run state.
## character_controller.gd inherits this. Keep game rules here, not class AI.

@export_group("Movement / Survival")
@export var move_speed: float = 6.0
@export var gravity: float = 20.0
@export var max_health: int = 100
@export var contact_damage_cooldown: float = 0.2
@export var dodge_speed: float = 16.0
@export var dodge_duration: float = 0.5
@export var max_dodge_energy: float = 100.0
@export var dodge_energy_cost: float = 50.0
@export var dodge_energy_regen: float = 10.0

@export_group("Progression")
@export var xp_to_level: int = 5
var current_xp: int = 0
var player_level: int = 1
var xp_multiplier: float = 1.0
var kill_count: int = 0
var run_time_seconds: float = 0.0
var run_ended: bool = false

var current_health: int = 100
var damage_reduction: float = 0.0
var tough_skin_stacks: int = 0
const TOUGH_SKIN_REDUCTION: float = 0.03
const TOUGH_SKIN_MAX_STACKS: int = 5
var ricochet_stacks: int = 0
var multishot_count: int = 1
var attack_range_multiplier: float = 1.0

@export_group("Blade Flurry")
@export var blade_flurry_level: int = 0
@export var blade_flurry_damage: int = 6
@export var blade_flurry_radius: float = 3.0
@export var blade_flurry_cooldown: float = 6.0
@export var blade_flurry_damage_per_milestone: int = 2

var projectile_damage: int = 10
var ranged_projectile_damage_bonus: int = 0
var fire_rate: float = 0.40
var godmode_enabled: bool = false
var is_invulnerable: bool = false
var is_dead: bool = false
var player_health_bar: Control = null
var upgrade_menu: Control = null
var hurt_cooldown_remaining: float = 0.0
var dodge_energy: float = 100.0
var dodge_time_remaining: float = 0.0
var dodge_direction: Vector3 = Vector3.ZERO

func _ready() -> void:
	add_to_group("player")
	current_health = max_health
	dodge_energy = max_dodge_energy
	run_time_seconds = 0.0
	run_ended = false
	call_deferred("_initialize_game_hud")
	if not has_node("BladeFlurry"):
		var blade_flurry = preload("res://Scripts/BladeFlurry.gd").new()
		blade_flurry.name = "BladeFlurry"
		add_child(blade_flurry)
	if not has_node("RangeIndicator"):
		var indicator = preload("res://Scripts/RangeIndicator.gd").new()
		indicator.name = "RangeIndicator"
		add_child(indicator)

func _initialize_game_hud() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	var root := tree.current_scene
	if root == null:
		return
	var fill := root.find_child("HealthFill", true, false)
	if fill != null:
		var candidate := fill.get_parent()
		if candidate is Control and candidate.has_method("set_health_values") and candidate.has_method("animate_xp"):
			player_health_bar = candidate as Control
	if player_health_bar == null:
		var candidate := root.find_child("PlayerHealthBar", true, false)
		if candidate is Control and candidate.has_method("set_health_values"):
			player_health_bar = candidate as Control
	upgrade_menu = root.find_child("UpgradeMenu", true, false) as Control
	if player_health_bar == null:
		push_warning("PlayerBase: PlayerHealthBar / HealthFill not found in active scene.")
	else:
		player_health_bar.call_deferred("set_health_immediate", float(current_health) / float(maxi(max_health, 1)))
		player_health_bar.call_deferred("set_health_values", current_health, max_health)
		player_health_bar.call_deferred("set_player_level", player_level)
		player_health_bar.call_deferred("set_xp_immediate", float(current_xp) / float(maxi(xp_to_level, 1)))
	_update_labels()

func _process(delta: float) -> void:
	if hurt_cooldown_remaining > 0.0:
		hurt_cooldown_remaining = maxf(0.0, hurt_cooldown_remaining - delta)
	if not is_dead and not run_ended:
		dodge_energy = minf(max_dodge_energy, dodge_energy + dodge_energy_regen * delta)
	if is_instance_valid(player_health_bar) and player_health_bar.has_method("set_dodge_energy"):
		player_health_bar.set_dodge_energy(dodge_energy, max_dodge_energy)

func take_damage(amount: int) -> void:
	if is_dead or godmode_enabled or is_invulnerable or hurt_cooldown_remaining > 0.0:
		return
	var actual_damage := maxi(0, roundi(float(amount) * (1.0 - clampf(damage_reduction, 0.0, 0.95))))
	current_health = maxi(current_health - actual_damage, 0)
	hurt_cooldown_remaining = contact_damage_cooldown
	refresh_health(true)
	if current_health <= 0:
		die()

func refresh_health(animated: bool = false) -> void:
	if not is_instance_valid(player_health_bar):
		_initialize_game_hud()
	if is_instance_valid(player_health_bar):
		var percent := float(current_health) / float(maxi(max_health, 1))
		if animated:
			player_health_bar.animate_health(percent)
		else:
			player_health_bar.set_health_immediate(percent)
		player_health_bar.set_health_values(current_health, max_health)
	_update_labels()

func gain_xp(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	current_xp += roundi(float(amount) * minf(xp_multiplier, 10.0))
	var leveled_up := false
	while current_xp >= xp_to_level:
		current_xp -= xp_to_level
		player_level += 1
		xp_to_level += 2
		leveled_up = true
	if not is_instance_valid(player_health_bar):
		_initialize_game_hud()
	if is_instance_valid(player_health_bar):
		player_health_bar.set_player_level(player_level)
		var percent := float(current_xp) / float(maxi(xp_to_level, 1))
		if leveled_up:
			player_health_bar.set_xp_immediate(percent)
		else:
			player_health_bar.animate_xp(percent)
	_update_labels()
	if leveled_up:
		if not is_instance_valid(upgrade_menu):
			upgrade_menu = get_tree().current_scene.find_child("UpgradeMenu", true, false) as Control
		if is_instance_valid(upgrade_menu) and upgrade_menu.has_method("show_upgrade_menu"):
			upgrade_menu.show_upgrade_menu()

func register_kill() -> void:
	kill_count += 1
	_update_labels()

func _update_labels() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var xp_label := root.find_child("XPLabel", true, false) as Label
	if xp_label != null:
		xp_label.text = "Level: %d | XP: %d / %d" % [player_level, current_xp, xp_to_level]
	var hp_label := root.find_child("HealthLabel", true, false) as Label
	if hp_label != null:
		hp_label.text = "Health: %d / %d" % [current_health, max_health]
	var kills_label := root.find_child("KillLabel", true, false) as Label
	if kills_label != null:
		kills_label.text = "Kills: %d" % kill_count

func upgrade_critical_strike() -> void:
	pass

func die() -> void:
	run_ended = true
	var menu := get_tree().current_scene.find_child("GameOverMenu", true, false) as Control
	if menu != null:
		menu.process_mode = Node.PROCESS_MODE_ALWAYS
		menu.show()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = true

func increased_attack_range() -> void:
	attack_range_multiplier += 0.05

func get_attack_damage_bonus(attack_tags: Array[String]) -> int:
	if attack_tags.has("ranged") or attack_tags.has("projectile"):
		return ranged_projectile_damage_bonus
	return 0

func try_spend_dodge_energy() -> bool:
	if dodge_energy < dodge_energy_cost:
		return false
	dodge_energy -= dodge_energy_cost
	return true

func get_dodge_energy_percent() -> float:
	return clampf(dodge_energy / maxf(max_dodge_energy, 1.0), 0.0, 1.0)
