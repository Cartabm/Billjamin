
extends Control

@onready var archer_button: Button = $CenterContainer/VBoxContainer/ArcherButton
@onready var rogue_button: Button = $CenterContainer/VBoxContainer/RogueButton
@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton


func _ready() -> void:
	archer_button.pressed.connect(_on_archer_pressed)
	rogue_button.pressed.connect(_on_rogue_pressed)
	back_button.pressed.connect(_on_back_pressed)


func _on_archer_pressed() -> void:
	CharacterManager.selected_class = CharacterManager.CharacterClass.ARCHER
	get_tree().change_scene_to_file("res://Scenes/Town.tscn")


func _on_rogue_pressed() -> void:
	CharacterManager.selected_class = CharacterManager.CharacterClass.ROGUE
	get_tree().change_scene_to_file("res://Scenes/Town.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
