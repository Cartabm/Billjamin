
extends Control

@onready var email_input: LineEdit = $CenterContainer/VBoxContainer/EmailInput
@onready var password_input: LineEdit = $CenterContainer/VBoxContainer/PasswordInput
@onready var create_account_button: Button = $CenterContainer/VBoxContainer/CreateAccountButton
@onready var sign_in_button: Button = $CenterContainer/VBoxContainer/SignInButton
@onready var status_label: Label = $CenterContainer/VBoxContainer/StatusLabel
@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton


func _ready() -> void:
	create_account_button.pressed.connect(_on_create_account_pressed)
	sign_in_button.pressed.connect(_on_sign_in_pressed)
	back_button.pressed.connect(_on_back_pressed)

	PlayerService.signup_finished.connect(_on_signup_finished)
	PlayerService.login_finished.connect(_on_login_finished)
	PlayerService.profile_loaded.connect(_on_profile_loaded)

	status_label.text = ""


func _exit_tree() -> void:
	if PlayerService.signup_finished.is_connected(_on_signup_finished):
		PlayerService.signup_finished.disconnect(_on_signup_finished)

	if PlayerService.login_finished.is_connected(_on_login_finished):
		PlayerService.login_finished.disconnect(_on_login_finished)

	if PlayerService.profile_loaded.is_connected(_on_profile_loaded):
		PlayerService.profile_loaded.disconnect(_on_profile_loaded)


func _on_create_account_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Account/CreateAccount.tscn")


func _on_sign_in_pressed() -> void:
	var email := email_input.text.strip_edges()
	var password := password_input.text

	if email.is_empty() or password.is_empty():
		status_label.text = "Enter your email and password."
		return

	_set_form_enabled(false)
	status_label.text = "Signing in..."

	PlayerService.sign_in(email, password)


func _on_signup_finished(success: bool, message: String) -> void:
	status_label.text = message

	if not success:
		_set_form_enabled(true)
		return

	password_input.clear()

	# Supabase may require email confirmation before a session exists.
	if PlayerService.is_authenticated:
		status_label.text = "Account created. Loading your profile..."
		PlayerService.load_profile()
	else:
		_set_form_enabled(true)


func _on_login_finished(success: bool, message: String) -> void:
	status_label.text = message

	if not success:
		_set_form_enabled(true)
		return

	password_input.clear()
	status_label.text = "Signed in. Loading your profile..."

	PlayerService.load_profile()


func _on_profile_loaded(
	success: bool,
	has_profile: bool,
	has_name: bool,
	message: String
) -> void:
	if not success:
		status_label.text = "Could not load your profile: " + message
		_set_form_enabled(true)
		return

	if has_profile and has_name:
		status_label.text = "Welcome back!"
		get_tree().change_scene_to_file("res://Scenes/Town.tscn")
	else:
		get_tree().change_scene_to_file("res://Scenes/ChoosePlayerName.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")


func _set_form_enabled(enabled: bool) -> void:
	create_account_button.disabled = not enabled
	sign_in_button.disabled = not enabled
	back_button.disabled = not enabled
	email_input.editable = enabled
	password_input.editable = enabled
