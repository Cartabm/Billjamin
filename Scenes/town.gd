extends Node3D

func _ready() -> void:
	if not CharacterManager.has_selected_character():
		push_warning("No character selected. Returning to Character Select.")
		_redirect_to_character_select.call_deferred()


func _redirect_to_character_select() -> void:
	get_tree().change_scene_to_file(
		"res://Scenes/CharacterSelect.tscn"
	)


func _on_proving_grounds_button_mouse_entered() -> void:
	pass # Replace with function body.


func _on_proving_grounds_button_mouse_exited() -> void:
	pass # Replace with function body.
