
extends Control

@onready var play_button: Button = $CenterContainer/VBoxContainer/PlayButton
@onready var options_button: Button = $CenterContainer/VBoxContainer/OptionsButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton


var checking_saved_session: bool = false
var saved_profile_checked: bool = false
var saved_profile_has_name: bool = false
var saved_profile_check_failed: bool = false
var loading_cloud_save: bool = false
var cloud_save_loaded: bool = false


func _ready() -> void:
	# --- CheddaBoards credentials (managed by Setup Wizard) ---
	CheddaBoards.set_api_key("cb_some-roguelike-hobby_54ee2684038bde7bd08acf99a6b21689")
	CheddaBoards.set_game_id("some-roguelike-hobby")
	# --- end CheddaBoards credentials ---

	play_button.pressed.connect(_on_play_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	PlayerService.save_loaded.connect(_on_cloud_save_loaded)

	PlayerService.session_restored.connect(_on_session_restored)
	PlayerService.profile_loaded.connect(_on_profile_loaded)

	# Keep the main menu visible while checking the saved session.
	checking_saved_session = true
	play_button.disabled = true

	if PlayerService.session_restore_finished:
		_on_session_restored(PlayerService.session_restore_succeeded)


func _exit_tree() -> void:
	if PlayerService.session_restored.is_connected(_on_session_restored):
		PlayerService.session_restored.disconnect(_on_session_restored)

	if PlayerService.profile_loaded.is_connected(_on_profile_loaded):
		PlayerService.profile_loaded.disconnect(_on_profile_loaded)

	if PlayerService.save_loaded.is_connected(_on_cloud_save_loaded):
		PlayerService.save_loaded.disconnect(_on_cloud_save_loaded)


func _on_session_restored(success: bool) -> void:
	if not checking_saved_session:
		return

	checking_saved_session = false
	play_button.disabled = false

	if not success:
		return

	PlayerService.load_profile()



func _on_profile_loaded(
	success: bool,
	has_profile: bool,
	has_name: bool,
	message: String
) -> void:
	if not PlayerService.is_authenticated:
		return

	saved_profile_checked = success
	saved_profile_has_name = has_profile and has_name
	saved_profile_check_failed = not success

	if not success:
		push_warning("Could not check the saved player profile: " + message)
		play_button.disabled = false




func _on_play_pressed() -> void:
	if checking_saved_session or loading_cloud_save:
		return

	if PlayerService.is_authenticated:
		if not saved_profile_checked:
			if saved_profile_check_failed:
				get_tree().change_scene_to_file("res://Scenes/AccountMenu.tscn")
			else:
				PlayerService.load_profile()
			return

		if saved_profile_has_name:
			if cloud_save_loaded:
				get_tree().change_scene_to_file("res://Scenes/CharacterSelect.tscn")
			else:
				loading_cloud_save = true
				play_button.disabled = true
				PlayerService.load_save()
		else:
			get_tree().change_scene_to_file("res://Scenes/ChoosePlayerName.tscn")
	else:
		get_tree().change_scene_to_file("res://Scenes/AccountMenu.tscn")


func _on_cloud_save_loaded(success: bool, message: String) -> void:
	loading_cloud_save = false
	print("CLOUD SAVE LOAD: ", success, " — ", message)

	if not success:
		play_button.disabled = false
		return

	cloud_save_loaded = true

	get_tree().change_scene_to_file("res://Scenes/CharacterSelect.tscn")



func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_options_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/optionsmenu.tscn")

