
extends RefCounted
class_name DamageCalculator

# Universal player damage calculation.
# Can be reused by projectiles, skills, spells,
# damage-over-time effects, and future abilities.

static func roll_damage(
	base_damage: int,
	min_multiplier: float = 0.80,
	max_multiplier: float = 1.20
) -> int:

	var minimum_damage: int = maxi(
		1,
		roundi(float(base_damage) * min_multiplier)
	)

	var maximum_damage: int = maxi(
		minimum_damage,
		roundi(float(base_damage) * max_multiplier)
	)

	return randi_range(minimum_damage, maximum_damage)


static func calculate_hit(
	base_damage: int,
	crit_chance: float,
	crit_multiplier: float,
	min_multiplier: float = 0.80,
	max_multiplier: float = 1.20
) -> Dictionary:

	# Roll damage independently for every attack.
	var rolled_damage: int = roll_damage(
		base_damage,
		min_multiplier,
		max_multiplier
	)

	# Roll critical chance separately.
	var is_critical: bool = randf() < clampf(
		crit_chance,
		0.0,
		1.0
	)

	var final_damage: int = rolled_damage

	if is_critical:
		final_damage = maxi(
			1,
			roundi(float(rolled_damage) * crit_multiplier)
		)

	return {
		"damage": final_damage,
		"is_critical": is_critical
	}
