extends Resource
class_name ItemRoll

# A unique rolled copy. Never modify ItemData to represent a dropped item.
@export var item_definition: ItemData
@export var quality: String = "Common"
@export var rolled_stats: Dictionary = {} # stat_id -> rolled numeric value
