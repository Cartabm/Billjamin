
extends Node

signal signup_finished(success: bool, message: String)
signal login_finished(success: bool, message: String)
signal session_restored(success: bool)
signal profile_loaded(success: bool, has_profile: bool, has_name: bool, message: String)
signal profile_created(success: bool, message: String)
signal save_loaded(success: bool, message: String)
signal save_saved(success: bool, message: String)

var player_save: PlayerSave

const SUPABASE_URL: String = "https://lpdjolhgqsixljrwngbb.supabase.co"
const SUPABASE_KEY: String = "sb_publishable_eFz2VJumefd_7iRxGcBO4Q_IdshILqM"
const SESSION_PATH: String = "user://player_session.cfg"

var player_id: String = ""
var player_name: String = ""
var is_authenticated: bool = false

var access_token: String = ""
var refresh_token: String = ""

var http: HTTPRequest
var current_action: String = ""

var session_restore_finished: bool = false
var session_restore_succeeded: bool = false


func _ready() -> void:
	http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_request_completed)
	
	player_save = PlayerSave.new()
	
	restore_session()


func _finish_session_restore(success: bool) -> void:
	session_restore_finished = true
	session_restore_succeeded = success
	session_restored.emit(success)


func restore_session() -> void:
	session_restore_finished = false
	session_restore_succeeded = false

	var config := ConfigFile.new()
	var error := config.load(SESSION_PATH)

	if error != OK:
		_finish_session_restore(false)
		return

	refresh_token = str(config.get_value("session", "refresh_token", ""))

	if refresh_token.is_empty():
		_finish_session_restore(false)
		return

	if not _can_start_request():
		_finish_session_restore(false)
		return

	current_action = "restore"

	var body := {
		"refresh_token": refresh_token
	}

	var request_error := _send_request(
		SUPABASE_URL + "/auth/v1/token?grant_type=refresh_token",
		body
	)

	if request_error != OK:
		current_action = ""
		clear_session()
		_finish_session_restore(false)


func save_session(data: Dictionary) -> void:
	access_token = str(data.get("access_token", ""))
	refresh_token = str(data.get("refresh_token", ""))

	var user_data: Dictionary = data.get("user", {})
	player_id = str(user_data.get("id", ""))
	is_authenticated = not player_id.is_empty()

	if access_token.is_empty() or refresh_token.is_empty():
		return

	var config := ConfigFile.new()
	config.set_value("session", "refresh_token", refresh_token)

	var error := config.save(SESSION_PATH)
	if error != OK:
		push_error("Could not save the session file.")


func clear_session() -> void:
	access_token = ""
	refresh_token = ""
	player_id = ""
	player_name = ""
	is_authenticated = false

	var config := ConfigFile.new()
	if config.load(SESSION_PATH) == OK:
		var dir := DirAccess.open("user://")
		if dir != null:
			dir.remove("player_session.cfg")


func create_account(email: String, password: String) -> void:
	if not _can_start_request():
		signup_finished.emit(false, "Another request is in progress.")
		return

	current_action = "signup"

	var body := {
		"email": email.strip_edges(),
		"password": password
	}

	var error := _send_request(
		SUPABASE_URL + "/auth/v1/signup",
		body
	)

	if error != OK:
		current_action = ""
		signup_finished.emit(false, "Could not start account creation.")


func sign_in(email: String, password: String) -> void:
	if not _can_start_request():
		login_finished.emit(false, "Another request is in progress.")
		return

	current_action = "login"

	var body := {
		"email": email.strip_edges(),
		"password": password
	}

	var error := _send_request(
		SUPABASE_URL + "/auth/v1/token?grant_type=password",
		body
	)

	if error != OK:
		current_action = ""
		login_finished.emit(false, "Could not start sign-in.")


func _can_start_request() -> bool:
	return (
		http != null
		and http.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED
		and current_action.is_empty()
	)


func _send_request(url: String, body: Dictionary) -> Error:
	var headers := PackedStringArray([
		"apikey: " + SUPABASE_KEY,
		"Content-Type: application/json"
	])

	return http.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)


func load_profile() -> void:
	if not is_authenticated or player_id.is_empty():
		profile_loaded.emit(false, false, false, "Please sign in first.")
		return

	if not _can_start_request():
		profile_loaded.emit(false, false, false, "Another request is in progress.")
		return

	current_action = "profile"

	var url := (
		SUPABASE_URL
		+ "/rest/v1/players?id=eq."
		+ player_id
		+ "&select=id,display_name"
	)

	var headers := PackedStringArray([
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + access_token,
		"Accept: application/json"
	])

	var error := http.request(
		url,
		headers,
		HTTPClient.METHOD_GET
	)

	if error != OK:
		current_action = ""
		profile_loaded.emit(false, false, false, "Could not start profile lookup.")


func create_profile(display_name: String) -> void:
	if not is_authenticated or player_id.is_empty():
		profile_created.emit(false, "Please sign in first.")
		return

	var clean_name := display_name.strip_edges()

	if clean_name.length() < 3 or clean_name.length() > 20:
		profile_created.emit(false, "Name must be 3–20 characters.")
		return

	if not _can_start_request():
		profile_created.emit(false, "Another request is in progress.")
		return

	current_action = "create_profile"

	var url := SUPABASE_URL + "/rest/v1/players"

	var headers := PackedStringArray([
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + access_token,
		"Content-Type: application/json",
		"Prefer: return=representation"
	])

	var body := {
		"id": player_id,
		"display_name": clean_name
	}

	var error := http.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)

	if error != OK:
		current_action = ""
		profile_created.emit(false, "Could not start profile creation.")



func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var response_text := body.get_string_from_utf8()
	var parsed: Variant = null

	if not response_text.is_empty():
		parsed = JSON.parse_string(response_text)
	var data: Dictionary = parsed if parsed is Dictionary else {}

	var previous_action := current_action
	current_action = ""

	# Network errors
	if result != HTTPRequest.RESULT_SUCCESS:
		if previous_action == "profile":
			profile_loaded.emit(false, false, false, "Network request failed.")
		elif previous_action == "create_profile":
			profile_created.emit(false, "Network request failed.")
		elif previous_action == "load_save":
			save_loaded.emit(false, "Cloud-save download failed.")
		elif previous_action == "save_save":
			save_saved.emit(false, "Cloud-save upload failed.")
		else:
			_handle_failure(previous_action, "Network request failed.")
		return

	# HTTP errors
	if response_code < 200 or response_code >= 300:
		var message := str(data.get(
			"msg",
			data.get(
				"message",
				data.get("error_description", "Request failed.")
			)
		))

		if previous_action == "profile":
			profile_loaded.emit(false, false, false, message)

		elif previous_action == "create_profile":
			if str(data.get("code", "")) == "23505":
				message = "That name is already taken. Choose another."
			elif str(data.get("code", "")) == "23503":
				message = "Your account profile could not be verified."
			profile_created.emit(false, message)

		elif previous_action == "load_save":
			save_loaded.emit(false, message)

		elif previous_action == "save_save":
			save_saved.emit(false, message)

		else:
			_handle_failure(previous_action, message)

		return

	# Successful account creation
	if previous_action == "signup":
		if data.has("access_token") and data.has("refresh_token"):
			save_session(data)
			signup_finished.emit(true, "Account created and signed in.")
		else:
			signup_finished.emit(
				true,
				"Account created. Check your email, then sign in."
			)

	# Successful login or session restoration
	elif previous_action == "login" or previous_action == "restore":
		if data.has("access_token") and data.has("refresh_token"):
			save_session(data)

			if previous_action == "login":
				login_finished.emit(true, "Signed in successfully.")
			else:
				_finish_session_restore(true)
		else:
			_handle_failure(previous_action, "Supabase returned no session.")

	# Profile lookup
	elif previous_action == "profile":
		if parsed is Array:
			if parsed.is_empty():
				player_name = ""
				profile_loaded.emit(
					true,
					false,
					false,
					"No player profile exists yet."
				)
			else:
				var profile: Dictionary = parsed[0]
				player_name = str(
					profile.get("display_name", "")
				).strip_edges()
				var has_name := not player_name.is_empty()

				profile_loaded.emit(
					true,
					true,
					has_name,
					"Profile loaded."
				)
		else:
			profile_loaded.emit(
				false,
				false,
				false,
				"Unexpected profile response."
			)

	# Player profile creation
	elif previous_action == "create_profile":
		if parsed is Array and not parsed.is_empty():
			var created_profile: Dictionary = parsed[0]
			player_name = str(
				created_profile.get("display_name", "")
			).strip_edges()

			if player_name.is_empty():
				profile_created.emit(
					false,
					"Supabase returned an empty player name."
				)
			else:
				profile_created.emit(true, "Player name saved.")
		else:
			profile_created.emit(
				false,
				"Profile response was unexpected."
			)

	# Cloud-save download
	elif previous_action == "load_save":
		if parsed is Array and not parsed.is_empty():
			var row: Dictionary = parsed[0]
			var save_data = row.get("data", {})

			if save_data is Dictionary:
				if player_save == null:
					player_save = PlayerSave.new()

				player_save.load_from_dictionary(save_data)
				player_save.player_id = player_id

				if player_save.display_name.is_empty():
					player_save.display_name = player_name

				save_loaded.emit(true, "Cloud save loaded.")
			else:
				save_loaded.emit(false, "Cloud-save data is invalid.")

		elif parsed is Array:
			# No cloud save exists yet; initialize a new one.
			player_save = PlayerSave.new()
			player_save.player_id = player_id
			player_save.display_name = player_name

			save_save()
			save_loaded.emit(true, "New save initialized.")
			
		else:
			save_loaded.emit(false, "Unexpected cloud-save response.")

	# Cloud-save upload
	elif previous_action == "save_save":
		save_saved.emit(true, "Cloud save saved.")

func _handle_failure(action: String, message: String) -> void:
	if action == "signup":
		signup_finished.emit(false, message)
	elif action == "login":
		login_finished.emit(false, message)
	elif action == "restore":
		clear_session()
		_finish_session_restore(false)
func load_save() -> void:
	if not is_authenticated or player_id.is_empty():
		save_loaded.emit(false, "Please sign in first.")
		return

	if not _can_start_request():
		save_loaded.emit(false, "Another request is in progress.")
		return

	current_action = "load_save"

	var url := (
		SUPABASE_URL
		+ "/rest/v1/player_saves?player_id=eq."
		+ player_id
		+ "&select=save_version,data"
	)

	var headers := PackedStringArray([
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + access_token,
		"Accept: application/json"
	])

	var error := http.request(
		url,
		headers,
		HTTPClient.METHOD_GET
	)

	if error != OK:
		current_action = ""
		save_loaded.emit(false, "Could not start cloud-save lookup.")


func save_save() -> void:
	if not is_authenticated or player_id.is_empty():
		save_saved.emit(false, "Please sign in first.")
		return

	if not _can_start_request():
		save_saved.emit(false, "Another request is in progress.")
		return

	if player_save == null:
		player_save = PlayerSave.new()

	player_save.player_id = player_id
	player_save.display_name = player_name

	current_action = "save_save"

	var url := (
		SUPABASE_URL
		+ "/rest/v1/player_saves?on_conflict=player_id"
	)

	var headers := PackedStringArray([
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + access_token,
		"Content-Type: application/json",
		"Prefer: resolution=merge-duplicates,return=minimal"
	])

	var body := {
		"player_id": player_id,
		"save_version": PlayerSave.CURRENT_SAVE_VERSION,
		"data": player_save.to_dictionary(),
		"updated_at": Time.get_datetime_string_from_system(true)
	}

	var error := http.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)

	if error != OK:
		current_action = ""
		save_saved.emit(false, "Could not start cloud-save upload.")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_authenticated and player_save != null:
			save_save()
