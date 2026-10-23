extends Control

@onready var email_input: LineEdit = $CenterContainer/VBoxContainer/EmailInput
@onready var password_input: LineEdit = $CenterContainer/VBoxContainer/PasswordInput
@onready var confirm_button: Button = $CenterContainer/VBoxContainer/ConfirmButton
@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton
@onready var status_label: Label = $CenterContainer/VBoxContainer/StatusLabel
@onready var verification_timer: Timer = $VerificationTimer

const MAX_VERIFICATION_CHECKS: int = 60

var pending_email: String = ""
var pending_password: String = ""
var waiting_for_verification: bool = false
var verification_checks: int = 0


func _ready() -> void:
	confirm_button.pressed.connect(_on_confirm_pressed)
	back_button.pressed.connect(_on_back_pressed)
	verification_timer.timeout.connect(_on_verification_timer_timeout)

	PlayerService.signup_finished.connect(_on_signup_finished)
	PlayerService.login_finished.connect(_on_login_finished)
	PlayerService.profile_loaded.connect(_on_profile_loaded)

	status_label.text = ""


func _exit_tree() -> void:
	verification_timer.stop()
	pending_password = ""

	if PlayerService.signup_finished.is_connected(_on_signup_finished):
		PlayerService.signup_finished.disconnect(_on_signup_finished)

	if PlayerService.login_finished.is_connected(_on_login_finished):
		PlayerService.login_finished.disconnect(_on_login_finished)

	if PlayerService.profile_loaded.is_connected(_on_profile_loaded):
		PlayerService.profile_loaded.disconnect(_on_profile_loaded)


func _on_confirm_pressed() -> void:
	var email := email_input.text.strip_edges()
	var password := password_input.text

	if email.is_empty() or password.is_empty():
		status_label.text = "Please enter your email and password."
		return

	pending_email = email
	pending_password = password

	confirm_button.disabled = true
	email_input.editable = false
	password_input.editable = false

	status_label.text = "Creating account..."

	PlayerService.create_account(email, password)


func _on_signup_finished(success: bool, message: String) -> void:
	if not success:
		status_label.text = message
		_reset_form()
		return

	if PlayerService.is_authenticated:
		_on_authenticated()
		return

	waiting_for_verification = true
	verification_checks = 0

	status_label.text = "Verification email sent. Check your inbox."
	password_input.clear()

	verification_timer.start()


func _on_verification_timer_timeout() -> void:
	if not waiting_for_verification:
		return

	if verification_checks >= MAX_VERIFICATION_CHECKS:
		verification_timer.stop()
		waiting_for_verification = false
		pending_password = ""
		status_label.text = "Verification timed out. Please sign in after verifying."
		return

	verification_checks += 1

	# Do not overlap requests handled by PlayerService.
	if not PlayerService.current_action.is_empty():
		return

	PlayerService.sign_in(pending_email, pending_password)


func _on_login_finished(success: bool, message: String) -> void:
	if not waiting_for_verification:
		return

	if success:
		_on_authenticated()
		return

	# Stop checking if Supabase rate-limits requests.
	var lower_message := message.to_lower()

	if "rate limit" in lower_message or "too many requests" in lower_message:
		verification_timer.stop()
		waiting_for_verification = false
		pending_password = ""
		status_label.text = "Too many attempts. Please sign in later."


func _on_authenticated() -> void:
	waiting_for_verification = false
	verification_timer.stop()
	pending_password = ""

	status_label.text = "Email verified! Loading your profile..."
	PlayerService.load_profile()


func _on_profile_loaded(
	success: bool,
	has_profile: bool,
	has_name: bool,
	message: String
) -> void:
	if not success:
		status_label.text = "Could not load profile: " + message
		return

	if has_profile and has_name:
		get_tree().change_scene_to_file("res://Scenes/CharacterSelect.tscn")
	else:
		get_tree().change_scene_to_file("res://Scenes/ChoosePlayerName.tscn")


func _on_back_pressed() -> void:
	verification_timer.stop()
	waiting_for_verification = false
	pending_password = ""

	get_tree().change_scene_to_file("res://Scenes/AccountMenu.tscn")


func _reset_form() -> void:
	confirm_button.disabled = false
	email_input.editable = true
	password_input.editable = true
	pending_password = ""
