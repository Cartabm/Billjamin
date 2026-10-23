
extends CanvasLayer

@onready var portal_prompt: Control = $PortalPrompt

@onready var proving_grounds_button: Button = $PortalPrompt/PanelContainer/VBoxContainer/ProvingGroundsButton
@onready var crucible_button: Button = $PortalPrompt/PanelContainer/VBoxContainer/CrucibleButton
@onready var wilds_button: Button = $PortalPrompt/PanelContainer/VBoxContainer/WildsButton
@onready var depths_button: Button = $PortalPrompt/PanelContainer/VBoxContainer/DepthsButton
@onready var return_button: Button = $PortalPrompt/PanelContainer/VBoxContainer/ReturnButton


func _ready() -> void:
	proving_grounds_button.pressed.connect(_on_proving_grounds_pressed)
	crucible_button.pressed.connect(_on_crucible_pressed)
	wilds_button.pressed.connect(_on_wilds_pressed)
	depths_button.pressed.connect(_on_depths_pressed)
	return_button.pressed.connect(_on_return_pressed)

	portal_prompt.hide()


func _on_proving_grounds_pressed() -> void:
	travel_to("res://Scenes/game.tscn")


func _on_crucible_pressed() -> void:
	travel_to("res://Scenes/arena.tscn")


func _on_wilds_pressed() -> void:
	travel_to("res://Art/Environment/OverworldTest.tscn")


func _on_depths_pressed() -> void:
	travel_to("res://World/Rooms/DungeonGeneratorTest.tscn")


func _on_return_pressed() -> void:
	portal_prompt.hide()


func travel_to(scene_path: String) -> void:
	if not ResourceLoader.exists(scene_path):
		push_error("Waystone destination not found: " + scene_path)
		return

	get_tree().paused = false
	get_tree().change_scene_to_file(scene_path)
