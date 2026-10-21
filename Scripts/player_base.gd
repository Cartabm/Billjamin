extends CharacterBody3D
## Shared player stats, XP, health, HUD, kills, and death handling.
## Class scripts inherit from this; do not attach it to a Control node.

@export_group("Movement / Survival")
@export var move_speed: float = 6.0
@export var gravity: float = 20.0
@export var max_health: int = 100
@export var contact_damage_cooldown: float = 1.0
@export var dodge_speed: float = 16.0
@export var dodge_duration: float = 0.5
@export var dodge_cooldown: float = 7.0

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


var projectile_damage: int = 10
var fire_rate: float = 0.40
var godmode_enabled: bool = false
var is_invulnerable: bool = false
var is_dead: bool = false
var player_health_bar: Control = null
var upgrade_menu: Control = null
var hurt_cooldown_remaining: float = 0.0
var dodge_cooldown_remaining: float = 0.0
var dodge_time_remaining: float = 0.0
var dodge_direction: Vector3 = Vector3.ZERO

func _ready() -> void:
	add_to_group("player")
	current_health = max_health
	run_time_seconds = 0.0
	run_ended = false
	call_deferred("_initialize_game_hud")

func _initialize_game_hud() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	# Locate the bar by its actual child, even if the HUD root has a different name.
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
		push_warning("PlayerBase: HUD bar not found. Check that HealthFill is a child of the Control with the health/XP script.")
	else:
		player_health_bar.call_deferred("set_health_immediate", float(current_health) / float(maxi(max_health, 1)))
		player_health_bar.call_deferred("set_health_values", current_health, max_health)
		player_health_bar.call_deferred("set_player_level", player_level)
		player_health_bar.call_deferred("set_xp_immediate", float(current_xp) / float(maxi(xp_to_level, 1)))
	_update_labels()

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
	var multiplier := minf(xp_multiplier, 10.0)
	current_xp += roundi(float(amount) * multiplier)
	var leveled_up := false
	var levels_gained := 0
	while current_xp >= xp_to_level:
		current_xp -= xp_to_level
		player_level += 1
		xp_to_level += 2
		leveled_up = true
		levels_gained += 1
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
	pass # Class-specific implementation overrides this.

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
