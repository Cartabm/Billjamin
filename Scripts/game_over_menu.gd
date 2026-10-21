extends Control


@onready var restart_button: Button = $RestartButton
@onready var return_to_town_button: Button = $ReturnToTownButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	restart_button.pressed.connect(_on_restart_pressed)
	return_to_town_button.pressed.connect(_on_return_to_town_pressed)


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_return_to_town_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/Town.tscn")
