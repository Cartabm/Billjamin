extends Resource
class_name ItemData

# Item definitions are templates, not equipped items or rolled loot instances.
@export var item_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var item_type: String = "Body Armor"
@export_range(1, 20, 1) var grid_width: int = 2
@export_range(1, 20, 1) var grid_height: int = 6
@export var quality: String = "Common"
@export var stats: Array[ItemStat] = []
