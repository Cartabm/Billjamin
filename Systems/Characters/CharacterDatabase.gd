
extends Node

signal characters_loaded(success: bool, message: String)
signal character_created(success: bool, message: String, character: Dictionary)
signal character_deleted(success: bool, message: String)

var characters: Array[Dictionary] = []
var loading: bool = false
var create_http: HTTPRequest
var http: HTTPRequest


func _ready() -> void:
	http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_request_completed)

	create_http = HTTPRequest.new()
	add_child(create_http)
	create_http.request_completed.connect(_on_create_character_completed)

	load_characters()


func load_characters() -> void:
	if loading:
		return

	if not PlayerService.is_authenticated:
		characters_loaded.emit(false, "Player is not signed in.")
		return

	if PlayerService.access_token.is_empty():
		characters_loaded.emit(false, "Authentication token is missing.")
		return

	loading = true

	var url := (
		PlayerService.SUPABASE_URL
		+ "/rest/v1/player_characters"
		+ "?select=id,character_name,class_id,personal_stash_unlocked,created_at"
		+ "&order=created_at.asc"
	)

	var headers := PackedStringArray([
		"apikey: " + PlayerService.SUPABASE_KEY,
		"Authorization: Bearer " + PlayerService.access_token,
		"Accept: application/json"
	])

	var error := http.request(url, headers, HTTPClient.METHOD_GET)

	if error != OK:
		loading = false
		characters_loaded.emit(false, "Could not start character request.")


func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	loading = false

	if result != HTTPRequest.RESULT_SUCCESS:
		characters_loaded.emit(false, "Network error loading characters.")
		return

	if response_code < 200 or response_code >= 300:
		characters_loaded.emit(
			false,
			"Supabase character error: HTTP " + str(response_code)
		)
		return

	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())

	if not parsed is Array:
		characters_loaded.emit(false, "Unexpected character response.")
		return

	var loaded_characters: Array[Dictionary] = []

	for entry in parsed:
		if entry is Dictionary:
			loaded_characters.append(entry)

	characters = loaded_characters

	characters_loaded.emit(true, "Characters loaded successfully.")


func create_character(class_id: String, character_name: String = "") -> void:
	if not PlayerService.is_authenticated:
		character_created.emit(false, "Player is not signed in.", {})
		return

	if PlayerService.access_token.is_empty():
		character_created.emit(false, "Authentication token is missing.", {})
		return

	if create_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		character_created.emit(false, "Character creation already in progress.", {})
		return

	var url := PlayerService.SUPABASE_URL + "/rest/v1/rpc/create_player_character"

	var headers := PackedStringArray([
		"apikey: " + PlayerService.SUPABASE_KEY,
		"Authorization: Bearer " + PlayerService.access_token,
		"Content-Type: application/json"
	])

	var body := {
		"p_class_id": class_id,
		"p_character_name": character_name
	}

	var error := create_http.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)

	if error != OK:
		character_created.emit(false, "Could not start character creation.", {})


func _on_create_character_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		character_created.emit(false, "Network error creating character.", {})
		return

	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())

	if response_code < 200 or response_code >= 300:
		var message := "Character creation failed."

		if parsed is Dictionary:
			message = str(parsed.get("message", message))

		character_created.emit(false, message, {})
		return

	if not parsed is Dictionary:
		character_created.emit(false, "Unexpected character response.", {})
		return

	var created_character: Dictionary = parsed
	characters.append(created_character)

	character_created.emit(
		true,
		"Character created successfully.",
		created_character
	)


func delete_character(character_id: String, confirmation: String) -> void:
	if not PlayerService.is_authenticated:
		character_deleted.emit(false, "Player is not signed in.")
		return

	if PlayerService.access_token.is_empty():
		character_deleted.emit(false, "Authentication token is missing.")
		return

	if character_id.is_empty():
		character_deleted.emit(false, "No character selected.")
		return

	if confirmation != "CONFIRM DELETE":
		character_deleted.emit(false, "Invalid confirmation.")
		return

	var delete_http := HTTPRequest.new()
	add_child(delete_http)

	delete_http.request_completed.connect(
		_on_delete_character_completed.bind(delete_http)
	)

	var url := (
		PlayerService.SUPABASE_URL
		+ "/rest/v1/rpc/delete_player_character"
	)

	var headers := PackedStringArray([
		"apikey: " + PlayerService.SUPABASE_KEY,
		"Authorization: Bearer " + PlayerService.access_token,
		"Content-Type: application/json"
	])

	var body := {
		"p_character_id": character_id,
		"p_confirmation": confirmation
	}

	var error := delete_http.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)

	if error != OK:
		delete_http.queue_free()
		character_deleted.emit(false, "Could not start deletion request.")


func _on_delete_character_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	delete_http: HTTPRequest
) -> void:
	delete_http.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS:
		character_deleted.emit(false, "Network error deleting character.")
		return

	if response_code < 200 or response_code >= 300:
		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		var message := "Character deletion failed. HTTP " + str(response_code)

		if parsed is Dictionary:
			message = str(parsed.get("message", message))

		character_deleted.emit(false, message)
		return

	character_deleted.emit(true, "Character deleted successfully.")
