extends RefCounted
class_name ItemRoller

const QUALITIES := ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic"]

# Generates one independent copy of an item. Call this when the loot system
# later decides which item and which quality to drop.
static func roll_item(definition: ItemData, quality: String = "", rng: RandomNumberGenerator = null) -> ItemRoll:
	if definition == null:
		return null
	var chosen_quality := quality if not quality.is_empty() else definition.quality
	if not QUALITIES.has(chosen_quality):
		push_warning("Unknown item quality: " + chosen_quality)
		return null
	var result := ItemRoll.new()
	result.item_definition = definition
	result.quality = chosen_quality
	for stat in definition.stats:
		if stat == null or stat.stat_id.is_empty():
			continue
		var bounds := stat.get_bounds(chosen_quality)
		var low: float = minf(bounds.x, bounds.y)
		var high: float = maxf(bounds.x, bounds.y)
		var rolled: float
		if is_equal_approx(low, roundf(low)) and is_equal_approx(high, roundf(high)):
			rolled = float(rng.randi_range(roundi(low), roundi(high)) if rng != null else randi_range(roundi(low), roundi(high)))
		else:
			rolled = snappedf(rng.randf_range(low, high) if rng != null else randf_range(low, high), 0.1)
		result.rolled_stats[stat.stat_id] = rolled
	return result
