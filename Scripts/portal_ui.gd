
extends CanvasLayer

@onready var portal_prompt: Control = $PortalPrompt
@onready var yes_button: Button = $PortalPrompt/PanelContainer/VBoxContainer/YesButton
@onready var no_button: Button = $PortalPrompt/PanelContainer/VBoxContainer/NoButton
@onready var arena_button: Button = $PortalPrompt/PanelContainer/VBoxContainer/ArenaButton
@onready var overworld_button: Button = $PortalPrompt/PanelContainer/VBoxContainer/OverworldButton


func _ready() -> void:
	yes_button.pressed.connect(_on_yes_pressed)
	no_button.pressed.connect(_on_no_pressed)
	arena_button.pressed.connect(_on_arena_pressed)
	overworld_button.pressed.connect(_on_overworld_pressed)

	portal_prompt.hide()


func _on_yes_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/game.tscn")


func _on_no_pressed() -> void:
	portal_prompt.hide()


func _on_arena_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/arena.tscn")


func _on_overworld_pressed() -> void:
	get_tree().change_scene_to_file("res://Art/Environment/OverworldTest.tscn")
