extends Resource
class_name UpgradeData

@export var upgrade_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

@export var required_tags: Array[String] = []

@export_range(1, 100, 1) var max_stacks: int = 1

@export_group("Effects")
@export var effects: Array[UpgradeEffect] = []
