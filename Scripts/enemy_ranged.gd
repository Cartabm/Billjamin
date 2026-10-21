extends "res://Scripts/enemy.gd"

# Inherits elite enemies, XP drops, damage numbers, player-level scaling,
# dungeon death signals, and HordeManager registration from enemy.gd.

@export_group("Ranged Enemy")
@export_range(0.1, 1.0, 0.05) var health_multiplier: float = 0.75
@export var preferred_distance: float = 7.0
@export var retreat_distance: float = 4.0
@export var attack_range: float = 13.0
@export var ranged_attack_damage: int = 10
@export var attack_interval: float = 2.0
@export var projectile_speed: float = 12.0
@export var projectile_spawn_height: float = 1.0
@export var projectile_scene: PackedScene = preload("res://Scenes/ranged_enemy_projectile.tscn")

var ranged_attack_timer: float = 1.0


func _ready() -> void:
	# Dungeon encounters apply their health multiplier before add_child().
	# Reduce the resulting health here, then let enemy.gd apply player-level
	# scaling and elite modifiers normally.
	max_health = maxi(1, roundi(float(max_health) * health_multiplier))
	# No melee contact damage: this enemy only hurts players with projectiles.
	contact_damage = 0
	super._ready()


func _horde_step(delta: float) -> void:
	if is_dying:
		return

	if player == null or not is_instance_valid(player):
		find_player()
	if player == null or not is_instance_valid(player):
		velocity = Vector3.ZERO
		return

	var toward: Vector3 = player.global_position - global_position
	toward.y = 0.0
	var distance: float = toward.length()
	var direction: Vector3 = toward.normalized() if distance > 0.01 else Vector3.ZERO

	if distance < retreat_distance:
		velocity.x = -direction.x * move_speed
		velocity.z = -direction.z * move_speed
	elif distance > preferred_distance:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	velocity.y = 0.0

	_horde_move(delta)
	update_sprite_facing()
	play_sprite_animation(&"Walk" if Vector2(velocity.x, velocity.z).length_squared() > 0.01 else &"Idle")

	ranged_attack_timer -= delta
	if ranged_attack_timer <= 0.0 and distance <= attack_range:
		_fire_projectile()
		ranged_attack_timer = maxf(0.1, attack_interval)


func _fire_projectile() -> void:
	if projectile_scene == null or player == null or not is_instance_valid(player):
		return

	var projectile := projectile_scene.instantiate() as Node3D
	if projectile == null:
		push_error("Ranged enemy projectile scene must have a Node3D root.")
		return

	var origin: Vector3 = global_position + Vector3.UP * projectile_spawn_height
	var target: Vector3 = player.global_position + Vector3.UP * 0.7
	var direction: Vector3 = (target - origin).normalized()
	var final_damage: int = _apply_elite_contact_damage(ranged_attack_damage)

	# Configure before entering the tree so the projectile is ready immediately.
	projectile.set("direction", direction)
	projectile.set("speed", projectile_speed)
	projectile.set("damage", final_damage)
	projectile.set("target_player", player)
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = origin
