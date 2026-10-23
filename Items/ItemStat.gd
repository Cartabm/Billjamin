extends Resource
class_name ItemStat

# Legacy fixed value, retained for existing v0.1 items.
@export var stat_id: String = ""
@export var value: float = 0.0

# When present, quality-specific ranges override the legacy fixed value.
@export var quality_ranges: Array[ItemStatRange] = []

func get_bounds(quality: String) -> Vector2:
	for entry in quality_ranges:
		if entry != null and entry.quality == quality:
			return Vector2(entry.min_value, entry.max_value)
	return Vector2(value, value)
