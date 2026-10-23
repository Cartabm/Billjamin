extends "res://Scripts/player_base.gd"

@export_group("Movement")
@export var acceleration: float = 30.0
@export var rotation_speed: float = 12.0

@export_group("Combat")
@export var melee_damage: int = 10
@export var melee_windup: float = 0.25
@export var auto_attack_enabled: bool = true
@export var attack_interval: float = 0.40
@export var auto_attack_range: float = 5.0
@export var melee_attack_angle: float = 90.0
@export var attack_speed: float = 1.0
@export_range(0.0, 1.0, 0.01) var critical_hit_chance: float = 0.05
@export var critical_damage_multiplier: float = 2.0
@export var minimum_damage_multiplier: float = 0.80
@export var maximum_damage_multiplier: float = 1.20

var is_attacking: bool = false
var melee_elapsed: float = 0.0
var melee_hit_applied: bool = false
var attack_cooldown: float = 0.0
var attack_tracking_target: Node3D = null
var melee_aim_angle: float = 0.0

@onready var character_model: Node3D = $CharacterModel
@onready var animation_player: AnimationPlayer = $CharacterModel/AnimationPlayer

func get_basic_attack_range() -> float:
	return auto_attack_range * attack_range_multiplier

func is_basic_range_indicator_applicable() -> bool:
	return auto_attack_enabled

func _ready() -> void:
	super._ready()
	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)
	animation_player.play("Idle")

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	hurt_cooldown_remaining = maxf(0.0, hurt_cooldown_remaining - delta)
	_handle_movement(delta)
	_handle_rotation(delta)
	_handle_animation()
	_handle_auto_attack(delta)
	_update_melee_attack(delta)

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
	if dodge_time_remaining > 0.0:
		return

	if not try_spend_dodge_energy():
		return

	var direction := _movement_direction()

	if direction.length_squared() < 0.01:
		direction = -character_model.global_basis.z
		direction.y = 0.0
		direction = direction.normalized()

	dodge_direction = direction
	dodge_time_remaining = dodge_duration
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
		attack_tracking_target = null
		is_attacking = false

func _handle_auto_attack(delta: float) -> void:
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	if not auto_attack_enabled or is_attacking or attack_cooldown > 0.0:
		return
	var nearest_enemy: Node3D = null
	var effective_range: float = get_basic_attack_range()
	var nearest_distance: float = effective_range * effective_range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node3D or enemy.is_queued_for_deletion():
			continue
		var offset: Vector3 = enemy.global_position - global_position
		offset.y = 0.0
		var distance: float = offset.length_squared()
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy
	if nearest_enemy == null:
		return
	var combat_settings := get_node_or_null("/root/CombatSettings")
	var use_auto_targeting: bool = true
	if combat_settings != null:
		use_auto_targeting = bool(combat_settings.get("auto_targeting_enabled"))
	if use_auto_targeting:
		attack_tracking_target = nearest_enemy
		_start_attack_at(nearest_enemy.global_position)
	else:
		attack_tracking_target = null
		var cursor_position: Variant = _get_cursor_world_position()
		if cursor_position != null:
			_start_attack_at(cursor_position)

func _get_cursor_world_position() -> Variant:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	var ground_plane := Plane(Vector3.UP, global_position.y)
	return ground_plane.intersects_ray(ray_origin, ray_direction)

func _start_attack_at(target_position: Vector3) -> void:
	if is_attacking:
		return
	is_attacking = true
	melee_elapsed = 0.0
	melee_hit_applied = false
	attack_cooldown = maxf(attack_interval, 0.01)
	var direction := target_position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		melee_aim_angle = atan2(-direction.x, -direction.z)
		character_model.rotation.y = melee_aim_angle + PI
	animation_player.play("Dagger_Attack", -1.0, attack_speed)

func _update_melee_attack(delta: float) -> void:
	if not is_attacking or melee_hit_applied:
		return
	if is_instance_valid(attack_tracking_target) and not attack_tracking_target.is_queued_for_deletion():
		var direction: Vector3 = attack_tracking_target.global_position - global_position
		direction.y = 0.0
		if direction.length_squared() > 0.001:
			melee_aim_angle = atan2(-direction.x, -direction.z)
			character_model.rotation.y = melee_aim_angle + PI
	melee_elapsed += delta
	if melee_elapsed >= maxf(melee_windup, 0.01):
		melee_hit_applied = true
		_apply_melee_damage()
		CombatVisualManager.player_slash(global_position, get_basic_attack_range(), melee_aim_angle, melee_attack_angle)
		attack_tracking_target = null

func _apply_melee_damage() -> void:
	var attack_direction := Vector3(-sin(melee_aim_angle), 0.0, -cos(melee_aim_angle))
	var effective_range: float = get_basic_attack_range()
	var range_squared: float = effective_range * effective_range
	var half_angle := deg_to_rad(melee_attack_angle * 0.5)
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
			enemy.take_projectile_hit(damage, critical)

func upgrade_critical_strike() -> void:
	critical_hit_chance = minf(1.0, critical_hit_chance + 0.05)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	is_attacking = false
	velocity = Vector3.ZERO
	animation_player.stop()
	super.die()
