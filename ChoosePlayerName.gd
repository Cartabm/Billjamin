
extends Control

@onready var name_input: LineEdit = $CenterContainer/VBoxContainer/NameInput
@onready var confirm_button: Button = $CenterContainer/VBoxContainer/ConfirmButton
@onready var status_label: Label = $CenterContainer/VBoxContainer/StatusLabel
@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton


func _ready() -> void:
	confirm_button.pressed.connect(_on_confirm_pressed)
	back_button.pressed.connect(_on_back_pressed)

	PlayerService.profile_created.connect(_on_profile_created)

	status_label.text = ""
	name_input.max_length = 20
	name_input.grab_focus()


func _exit_tree() -> void:
	if PlayerService.profile_created.is_connected(_on_profile_created):
		PlayerService.profile_created.disconnect(_on_profile_created)


func _on_confirm_pressed() -> void:
	var chosen_name := name_input.text.strip_edges()

	if chosen_name.length() < 3 or chosen_name.length() > 20:
		status_label.text = "Name must be 3–20 characters."
		return

	confirm_button.disabled = true
	back_button.disabled = true
	name_input.editable = false
	status_label.text = "Saving player name..."

	PlayerService.create_profile(chosen_name)


func _on_profile_created(success: bool, message: String) -> void:
	status_label.text = message

	if not success:
		confirm_button.disabled = false
		back_button.disabled = false
		name_input.editable = true
		return

	get_tree().change_scene_to_file("res://Town.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://MainMenu.tscn")
