extends RefCounted
class_name UpgradeApplier


static func apply_upgrade(upgrade: UpgradeData, target: Object) -> bool:
	if upgrade == null or target == null:
		return false

	var all_successful := true

	for effect in upgrade.effects:
		if effect == null:
			continue

		if not apply_effect(effect, target):
			all_successful = false

	return all_successful


static func apply_effect(effect: UpgradeEffect, target: Object) -> bool:
	if effect == null or target == null:
		return false

	var stat_name := effect.stat_name.strip_edges()

	if stat_name.is_empty():
		push_warning("UpgradeApplier: Effect has no stat name.")
		return false

	var property_found := false

	for property_info in target.get_property_list():
		if String(property_info["name"]) == stat_name:
			property_found = true
			break

	if not property_found:
		push_warning("UpgradeApplier: Stat '%s' does not exist on target." % stat_name)
		return false

	var current_value: Variant = target.get(stat_name)

	if typeof(current_value) != TYPE_INT and typeof(current_value) != TYPE_FLOAT:
		push_warning("UpgradeApplier: Stat '%s' is not numeric." % stat_name)
		return false

	var new_value: float = float(current_value)

	match effect.operation:
		UpgradeEffect.Operation.ADD:
			new_value += effect.value

		UpgradeEffect.Operation.MULTIPLY:
			new_value *= effect.value

		UpgradeEffect.Operation.SET:
			new_value = effect.value

		_:
			return false

	if typeof(current_value) == TYPE_INT:
		target.set(stat_name, roundi(new_value))
	else:
		target.set(stat_name, new_value)

	return true
