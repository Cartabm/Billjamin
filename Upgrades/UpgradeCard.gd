extends Button
class_name UpgradeCard

signal upgrade_selected(upgrade: UpgradeData)

@export var upgrade_data: UpgradeData

# Uses the SAME node hierarchy and appearance as your PowerShotButton.
@onready var ability_icon: TextureRect = get_node_or_null("AbilityIcon") as TextureRect
@onready var name_label: Label = get_node_or_null("CardText/UpgradeName") as Label
@onready var description_label: Label = get_node_or_null("CardText/UpgradeDescription") as Label


func _ready() -> void:
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	refresh_card()


func set_upgrade(data: UpgradeData) -> void:
	upgrade_data = data
	if is_node_ready():
		refresh_card()


func refresh_card() -> void:
	if upgrade_data == null:
		return
	text = ""
	if name_label != null:
		name_label.text = upgrade_data.upgrade_name
	if description_label != null:
		description_label.text = upgrade_data.description
	if ability_icon != null:
		ability_icon.texture = upgrade_data.icon
		ability_icon.visible = upgrade_data.icon != null


func _on_pressed() -> void:
	if upgrade_data != null:
		upgrade_selected.emit(upgrade_data)
