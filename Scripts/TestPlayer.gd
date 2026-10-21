extends CharacterBody3D

# Rogue baseline matched to the Archer's starting damage, crits, and movement.
@export_group("Movement")
@export var move_speed: float = 6.0
@export var acceleration: float = 30.0
@export var gravity: float = 20.0
@export var rotation_speed: float = 12.0

@export_group("Combat")
@export var melee_damage: int = 10
@export var melee_windup: float = 0.25
@export var auto_attack_enabled: bool = true
@export var attack_interval: float = 0.40
@export var auto_attack_range: float = 5.0
@export var attack_speed: float = 1.0
@export_range(0.0, 1.0, 0.01) var critical_hit_chance: float = 0.05
@export var critical_damage_multiplier: float = 2.0
@export var minimum_damage_multiplier: float = 0.80
@export var maximum_damage_multiplier: float = 1.20

@export_group("Survival")
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
var damage_reduction: float = 0.0
var tough_skin_stacks: int = 0
var ricochet_stacks: int = 0
var multishot_count: int = 1
# Compatibility for upgrade scripts that expect the Archer's ranged stat.
var projectile_damage: int = 10
var fire_rate: float = 0.40
var godmode_enabled: bool = false

var player_health_bar: Control
var current_health: int = 100
var is_dead: bool = false
var is_attacking: bool = false
var melee_elapsed: float = 0.0
var melee_hit_applied: bool = false
var attack_cooldown: float = 0.0
var hurt_cooldown_remaining: float = 0.0
var dodge_cooldown_remaining: float = 0.0
var dodge_time_remaining: float = 0.0
var dodge_direction: Vector3 = Vector3.ZERO
var is_invulnerable: bool = false

@onready var character_model: Node3D = $CharacterModel
@onready var animation_player: AnimationPlayer = $CharacterModel/AnimationPlayer
@onready var melee_telegraph: MeshInstance3D = $MeleeTelegraph

func _ready() -> void:
	add_to_group("player")
	current_health = max_health
	projectile_damage = melee_damage
	fire_rate = attack_interval
	animation_player.animation_finished.connect(_on_animation_finished)
	animation_player.play("Idle")
	call_deferred("_initialize_game_hud")
	_update_hud()

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	hurt_cooldown_remaining = maxf(0.0, hurt_cooldown_remaining - delta)
	dodge_cooldown_remaining = maxf(0.0, dodge_cooldown_remaining - delta)
	_handle_movement(delta)
	_handle_rotation(delta)
	_handle_animation()
	_handle_auto_attack(delta)
	_update_melee_telegraph(delta)

func _input(event: InputEvent) -> void:
	if is_dead:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_start_dodge()

func _movement_direction() -> Vector3:
	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A): input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D): input_dir.x += 1.0
	if Input.is_key_pressed(KEY_W): input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S): input_dir.y += 1.0
	input_dir = input_dir.normalized()
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3(input_dir.x, 0.0, input_dir.y)
	var forward := -cam.global_basis.z
	var right := cam.global_basis.x
	forward.y = 0.0
	right.y = 0.0
	return (right.normalized() * input_dir.x - forward.normalized() * input_dir.y).normalized()

func _handle_movement(delta: float) -> void:
	var direction := _movement_direction()
	if dodge_time_remaining > 0.0:
		dodge_time_remaining = maxf(0.0, dodge_time_remaining - delta)
		velocity.x = dodge_direction.x * dodge_speed
		velocity.z = dodge_direction.z * dodge_speed
		if dodge_time_remaining <= 0.0:
			is_invulnerable = false
	else:
		velocity.x = move_toward(velocity.x, direction.x * move_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * move_speed, acceleration * delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()

func _start_dodge() -> void:
	if dodge_cooldown_remaining > 0.0 or dodge_time_remaining > 0.0:
		return
	var direction := _movement_direction()
	if direction.length_squared() < 0.01:
		direction = -character_model.global_basis.z
		direction.y = 0.0
		direction = direction.normalized()
	dodge_direction = direction
	dodge_time_remaining = dodge_duration
	dodge_cooldown_remaining = dodge_cooldown
	is_invulnerable = true

func _handle_rotation(delta: float) -> void:
	if is_attacking:
		return
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	if horizontal_velocity.length_squared() > 0.01:
		var target_angle := atan2(-horizontal_velocity.x, -horizontal_velocity.z) + PI
		character_model.rotation.y = lerp_angle(character_model.rotation.y, target_angle, clampf(rotation_speed * delta, 0.0, 1.0))

func _handle_animation() -> void:
	if is_attacking:
		return
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var desired_animation := "Run" if horizontal_velocity.length_squared() > 0.01 else "Idle"
	if animation_player.current_animation != desired_animation:
		animation_player.play(desired_animation)

func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"Dagger_Attack":
		melee_telegraph.hide()
		is_attacking = false

func _handle_auto_attack(delta: float) -> void:
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	if not auto_attack_enabled or is_attacking or attack_cooldown > 0.0:
		return
	var nearest_enemy: Node3D = null
	var nearest_distance := auto_attack_range * auto_attack_range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node3D or enemy.is_queued_for_deletion():
			continue
		var distance := global_position.distance_squared_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy
	if nearest_enemy != null:
		_start_attack_at(nearest_enemy.global_position)

func _start_attack_at(target_position: Vector3) -> void:
	if is_attacking:
		return
	is_attacking = true
	melee_elapsed = 0.0
	melee_hit_applied = false
	melee_telegraph.set_charge(0.0)
	attack_cooldown = maxf(attack_interval, 0.01)
	var direction := target_position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		var aim_angle := atan2(-direction.x, -direction.z)
		character_model.rotation.y = aim_angle + PI
		melee_telegraph.rotation.y = aim_angle
	melee_telegraph.show()
	animation_player.play("Dagger_Attack", -1.0, attack_speed)

func _update_melee_telegraph(delta: float) -> void:
	if not is_attacking or melee_hit_applied:
		return
	melee_elapsed += delta
	var progress := clampf(melee_elapsed / maxf(melee_windup, 0.01), 0.0, 1.0)
	melee_telegraph.set_charge(progress)
	if progress >= 1.0:
		melee_hit_applied = true
		_apply_melee_damage()
		melee_telegraph.hide()

func _apply_melee_damage() -> void:
	var attack_direction := Vector3(-sin(melee_telegraph.rotation.y), 0.0, -cos(melee_telegraph.rotation.y))
	var range_squared: float = float(melee_telegraph.attack_range) * float(melee_telegraph.attack_range)
	var half_angle := deg_to_rad(float(melee_telegraph.attack_angle) * 0.5)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node3D or enemy.is_queued_for_deletion():
			continue
		var direction: Vector3 = enemy.global_position - global_position
		direction.y = 0.0
		if direction.length_squared() > range_squared or direction.length_squared() < 0.0001:
			continue
		if attack_direction.angle_to(direction.normalized()) <= half_angle and enemy.has_method("take_damage"):
			var damage := maxi(1, roundi(float(melee_damage) * randf_range(minimum_damage_multiplier, maximum_damage_multiplier)))
			var critical := randf() < critical_hit_chance
			if critical:
				damage = maxi(1, roundi(float(damage) * critical_damage_multiplier))
			# Existing enemies accept take_damage(amount); avoid changing that contract.
			enemy.take_damage(damage)

func take_damage(amount: int) -> void:
	if is_dead or godmode_enabled or is_invulnerable or hurt_cooldown_remaining > 0.0:
		return
	var actual_damage := maxi(0, roundi(float(amount) * (1.0 - clampf(damage_reduction, 0.0, 0.95))))
	current_health = maxi(current_health - actual_damage, 0)
	hurt_cooldown_remaining = contact_damage_cooldown
	print("ROGUE HIT | Damage: ", actual_damage, " | Health: ", current_health, "/", max_health)
	_update_hud(true, false)
	if current_health <= 0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	is_attacking = false
	velocity = Vector3.ZERO
	melee_telegraph.hide()
	animation_player.stop()
	print("ROGUE DIED — GAME OVER")
	var menu := get_tree().current_scene.find_child("GameOverMenu", true, false)
	if menu is CanvasItem:
		menu.show()

func gain_xp(amount: int) -> void:
	if is_dead:
		return
	current_xp += maxi(0, roundi(float(amount) * xp_multiplier))
	while current_xp >= xp_to_level:
		current_xp -= xp_to_level
		player_level += 1
		xp_to_level += 2
		print("ROGUE LEVEL UP: ", player_level)
		var menu := get_tree().current_scene.find_child("UpgradeMenu", true, false)
		if menu != null and menu.has_method("show_upgrade_menu"):
			menu.call("show_upgrade_menu")
	_update_hud(false, true)

func register_kill() -> void:
	kill_count += 1
	_update_hud()

func upgrade_critical_strike() -> void:
	critical_hit_chance = minf(1.0, critical_hit_chance + 0.05)

func _initialize_game_hud() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	# Works with GameHUD instanced beneath CanvasLayer or elsewhere.
	var hud := root.find_child("GameHUD", true, false)
	if hud == null:
		push_warning("Rogue: GameHUD not found in current scene. Instance GameHUD.tscn in OverworldTest.tscn.")
		return
	player_health_bar = hud.find_child("PlayerHealthBar", true, false) as Control
	if player_health_bar == null:
		var health_fill := hud.find_child("HealthFill", true, false)
		if health_fill != null:
			player_health_bar = health_fill.get_parent() as Control
	if player_health_bar == null:
		push_warning("Rogue: Could not locate HUD health bar.")
	_update_hud(false, true)

func _update_hud(animate_hp: bool = false, animate_xp_bar: bool = false) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	if is_instance_valid(player_health_bar):
		var hp_ratio := float(current_health) / float(maxi(max_health, 1))
		if animate_hp:
			player_health_bar.call("animate_health", hp_ratio)
		else:
			player_health_bar.call("set_health_immediate", hp_ratio)
		player_health_bar.call("set_health_values", current_health, max_health)
		player_health_bar.call("set_player_level", player_level)
		var xp_ratio := float(current_xp) / float(maxi(xp_to_level, 1))
		if animate_xp_bar:
			player_health_bar.call("animate_xp", xp_ratio)
		else:
			player_health_bar.call("set_xp_immediate", xp_ratio)
	var xp_label := root.find_child("XPLabel", true, false) as Label
	if xp_label != null:
		xp_label.text = "Level: %d | XP: %d / %d" % [player_level, current_xp, xp_to_level]
	var health_label := root.find_child("HealthLabel", true, false) as Label
	if health_label != null:
		health_label.text = "Health: %d / %d" % [current_health, max_health]
	var kill_label := root.find_child("KillLabel", true, false) as Label
	if kill_label != null:
		kill_label.text = "Kills: %d" % kill_count
