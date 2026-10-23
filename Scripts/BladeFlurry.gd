
extends Node3D
## Universal Blade Flurry: damage independent of optional visual effects.

var player: CharacterBody3D = null
var cooldown_remaining: float = 0.0

func _ready() -> void:
	player = get_parent() as CharacterBody3D

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	if player.is_dead or player.run_ended or player.blade_flurry_level <= 0:
		return
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	if cooldown_remaining <= 0.0:
		_try_activate()

func get_effective_radius() -> float:
	var level: int = player.blade_flurry_level
	var milestones: int = level / 5
	var radius_levels: int = maxi(0, level - 1 - milestones)
	var radius_multiplier: float = 1.0 + float(radius_levels) * 0.05
	return player.blade_flurry_radius * radius_multiplier * player.attack_range_multiplier

func get_effective_damage() -> int:
	var milestones: int = player.blade_flurry_level / 5
	return player.blade_flurry_damage + milestones * player.blade_flurry_damage_per_milestone

func _try_activate() -> void:
	var radius: float = get_effective_radius()
	var radius_squared: float = radius * radius
	var targets: Array[Node3D] = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node3D or enemy.is_queued_for_deletion():
			continue
		if not enemy.has_method("take_damage"):
			continue
		var offset: Vector3 = enemy.global_position - player.global_position
		offset.y = 0.0
		if offset.length_squared() <= radius_squared:
			targets.append(enemy)
	if targets.is_empty():
		return
	cooldown_remaining = player.blade_flurry_cooldown
	# Impact happens immediately; the expanding ring explains its true reach.
	CombatVisualManager.player_burst(player.global_position, radius)
	CombatVisualManager.player_slash(player.global_position, radius, 0.0, 270.0)
	for enemy in targets:
		if not is_instance_valid(enemy):
			continue
		var attack_tags: Array[String] = ["projectile", "area"]
		var damage: int = get_effective_damage() + player.get_attack_damage_bonus(attack_tags)
		var crit_chance: float = float(player.get("critical_hit_chance"))
		var crit_multiplier: float = float(player.get("critical_damage_multiplier"))
		var critical: bool = randf() < crit_chance

		if critical:
			damage = maxi(1, roundi(float(damage) * crit_multiplier))

		enemy.take_projectile_hit(damage, critical)
