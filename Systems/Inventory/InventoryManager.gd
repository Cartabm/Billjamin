
extends Node

signal inventory_loaded(success: bool, message: String)
signal item_move_completed(success: bool, message: String)
signal item_drop_completed(success: bool, message: String)
signal item_pickup_completed(success: bool, message: String)
signal ground_items_loaded(success: bool, message: String)

var items: Array[Dictionary] = []

var loading: bool = false
var loading_character_id: String = ""

var moving_item: bool = false
var moving_character_id: String = ""

var dropping_item: bool = false
var dropping_character_id: String = ""

var picking_up_item: bool = false
var pickup_character_id: String = ""

var http: HTTPRequest
var move_http: HTTPRequest
var drop_http: HTTPRequest
var pickup_http: HTTPRequest

var ground_items: Array[Dictionary] = []
var ground_http: HTTPRequest
var loading_ground_items: bool = false
var ground_loading_character_id: String = ""


func _ready() -> void:
	http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_request_completed)

	move_http = HTTPRequest.new()
	add_child(move_http)
	move_http.request_completed.connect(_on_move_request_completed)

	drop_http = HTTPRequest.new()
	add_child(drop_http)
	drop_http.request_completed.connect(_on_drop_request_completed)

	pickup_http = HTTPRequest.new()
	add_child(pickup_http)
	pickup_http.request_completed.connect(_on_pickup_request_completed)

	ground_http = HTTPRequest.new()
	add_child(ground_http)
	ground_http.request_completed.connect(_on_ground_items_request_completed)


# ============================================================
# LOAD INVENTORY
# ============================================================

func load_inventory() -> void:
	if loading:
		return

	if moving_item or dropping_item or picking_up_item:
		inventory_loaded.emit(
			false,
			"Wait for the current inventory operation to finish."
		)
		return

	if not PlayerService.is_authenticated:
		inventory_loaded.emit(false, "Player is not signed in.")
		return

	if PlayerService.player_id.is_empty():
		inventory_loaded.emit(false, "Player ID is missing.")
		return

	if PlayerService.access_token.is_empty():
		inventory_loaded.emit(false, "Authentication token is missing.")
		return

	if not CharacterManager.has_selected_character():
		inventory_loaded.emit(false, "No character selected.")
		return

	loading = true
	loading_character_id = CharacterManager.selected_character_id
	items.clear()

	var character_id: String = CharacterManager.selected_character_id

	var url := (
		PlayerService.SUPABASE_URL
		+ "/rest/v1/player_items"
		+ "?select=*"
		+ "&player_id=eq." + PlayerService.player_id
		+ "&or=(character_id.eq." + character_id + ",and(character_id.is.null,location.eq.shared_stash))"
		+ "&order=created_at.desc"
	)

	var headers := PackedStringArray([
		"apikey: " + PlayerService.SUPABASE_KEY,
		"Authorization: Bearer " + PlayerService.access_token,
		"Accept: application/json"
	])

	var error := http.request(
		url,
		headers,
		HTTPClient.METHOD_GET
	)

	if error != OK:
		loading = false
		loading_character_id = ""
		inventory_loaded.emit(
			false,
			"Could not start inventory request."
		)


func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	loading = false

	# Ignore results if the selected character changed.
	if not CharacterManager.has_selected_character() \
	or CharacterManager.selected_character_id != loading_character_id:
		loading_character_id = ""
		items.clear()
		inventory_loaded.emit(
			false,
			"Inventory request cancelled: character changed."
		)
		return

	loading_character_id = ""

	if result != HTTPRequest.RESULT_SUCCESS:
		inventory_loaded.emit(
			false,
			"Network error loading inventory."
		)
		return

	if response_code < 200 or response_code >= 300:
		inventory_loaded.emit(
			false,
			"Supabase inventory error: HTTP " + str(response_code)
		)
		return

	var parsed: Variant = JSON.parse_string(
		body.get_string_from_utf8()
	)

	if not parsed is Array:
		inventory_loaded.emit(
			false,
			"Unexpected inventory response."
		)
		return

	items.clear()

	for entry in parsed:
		if entry is Dictionary:
			items.append(entry)

	inventory_loaded.emit(
		true,
		"Inventory loaded successfully."
	)


# ============================================================
# MOVE INVENTORY ITEM
# ============================================================

func move_item(
	item_id: String,
	grid_x: int,
	grid_y: int
) -> void:
	if moving_item or dropping_item or picking_up_item:
		item_move_completed.emit(
			false,
			"Another item operation is in progress."
		)
		return

	if loading:
		item_move_completed.emit(
			false,
			"Wait for inventory loading to finish."
		)
		return

	if not PlayerService.is_authenticated:
		item_move_completed.emit(
			false,
			"Player is not signed in."
		)
		return

	if PlayerService.access_token.is_empty():
		item_move_completed.emit(
			false,
			"Authentication token is missing."
		)
		return

	if not CharacterManager.has_selected_character():
		item_move_completed.emit(
			false,
			"No character selected."
		)
		return

	moving_item = true
	moving_character_id = CharacterManager.selected_character_id

	var url := (
		PlayerService.SUPABASE_URL
		+ "/rest/v1/rpc/move_inventory_item"
	)

	var headers := PackedStringArray([
		"apikey: " + PlayerService.SUPABASE_KEY,
		"Authorization: Bearer " + PlayerService.access_token,
		"Content-Type: application/json"
	])

	var body := JSON.stringify({
		"p_item_id": item_id,
		"p_character_id": moving_character_id,
		"p_grid_x": grid_x,
		"p_grid_y": grid_y
	})

	var error := move_http.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		body
	)

	if error != OK:
		moving_item = false
		moving_character_id = ""
		item_move_completed.emit(
			false,
			"Could not start item movement request."
		)


func _on_move_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	moving_item = false

	if not CharacterManager.has_selected_character() \
	or CharacterManager.selected_character_id != moving_character_id:
		moving_character_id = ""
		item_move_completed.emit(
			false,
			"Item movement response ignored: character changed."
		)
		return

	moving_character_id = ""

	if result != HTTPRequest.RESULT_SUCCESS:
		item_move_completed.emit(
			false,
			"Network error moving item."
		)
		return

	if response_code < 200 or response_code >= 300:
		item_move_completed.emit(
			false,
			"Supabase error: " + body.get_string_from_utf8()
		)
		return

	var parsed: Variant = JSON.parse_string(
		body.get_string_from_utf8()
	)

	if parsed != true:
		item_move_completed.emit(
			false,
			"Item movement was not confirmed by the server."
		)
		return

	item_move_completed.emit(
		true,
		"Item moved successfully."
	)


# ============================================================
# DROP INVENTORY ITEM
# ============================================================

func drop_item(
	item_id: String,
	world_position: Vector3,
	scene_id: String
) -> void:
	if dropping_item or moving_item or picking_up_item or loading:
		item_drop_completed.emit(
			false,
			"Another inventory operation is in progress."
		)
		return

	if not PlayerService.is_authenticated:
		item_drop_completed.emit(
			false,
			"Player is not signed in."
		)
		return

	if PlayerService.access_token.is_empty():
		item_drop_completed.emit(
			false,
			"Authentication token is missing."
		)
		return

	if not CharacterManager.has_selected_character():
		item_drop_completed.emit(
			false,
			"No character selected."
		)
		return

	dropping_item = true
	dropping_character_id = CharacterManager.selected_character_id

	var url := (
		PlayerService.SUPABASE_URL
		+ "/rest/v1/rpc/drop_inventory_item"
	)

	var headers := PackedStringArray([
		"apikey: " + PlayerService.SUPABASE_KEY,
		"Authorization: Bearer " + PlayerService.access_token,
		"Content-Type: application/json"
	])

	var body := JSON.stringify({
		"p_item_id": item_id,
		"p_character_id": dropping_character_id,
		"p_world_x": world_position.x,
		"p_world_y": world_position.y,
		"p_world_z": world_position.z,
		"p_scene_id": scene_id
	})

	var error := drop_http.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		body
	)

	if error != OK:
		dropping_item = false
		dropping_character_id = ""
		item_drop_completed.emit(
			false,
			"Could not start item drop request."
		)


func _on_drop_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	dropping_item = false

	if not CharacterManager.has_selected_character() \
	or CharacterManager.selected_character_id != dropping_character_id:
		dropping_character_id = ""
		item_drop_completed.emit(
			false,
			"Item drop response ignored: character changed."
		)
		return

	dropping_character_id = ""

	if result != HTTPRequest.RESULT_SUCCESS:
		item_drop_completed.emit(
			false,
			"Network error dropping item."
		)
		return

	if response_code < 200 or response_code >= 300:
		item_drop_completed.emit(
			false,
			"Supabase error: " + body.get_string_from_utf8()
		)
		return

	var parsed: Variant = JSON.parse_string(
		body.get_string_from_utf8()
	)

	if parsed != true:
		item_drop_completed.emit(
			false,
			"Item drop was not confirmed by the server."
		)
		return

	item_drop_completed.emit(
		true,
		"Item dropped successfully."
	)


# ============================================================
# PICK UP GROUND ITEM
# ============================================================

func pickup_item(item_id: String) -> void:
	if picking_up_item or dropping_item or moving_item or loading:
		item_pickup_completed.emit(
			false,
			"Another inventory operation is in progress."
		)
		return

	if not PlayerService.is_authenticated:
		item_pickup_completed.emit(
			false,
			"Player is not signed in."
		)
		return

	if PlayerService.access_token.is_empty():
		item_pickup_completed.emit(
			false,
			"Authentication token is missing."
		)
		return

	if not CharacterManager.has_selected_character():
		item_pickup_completed.emit(
			false,
			"No character selected."
		)
		return

	picking_up_item = true
	pickup_character_id = CharacterManager.selected_character_id

	var url := (
		PlayerService.SUPABASE_URL
		+ "/rest/v1/rpc/pickup_ground_item"
	)

	var headers := PackedStringArray([
		"apikey: " + PlayerService.SUPABASE_KEY,
		"Authorization: Bearer " + PlayerService.access_token,
		"Content-Type: application/json"
	])

	var body := JSON.stringify({
		"p_item_id": item_id,
		"p_character_id": pickup_character_id
	})

	var error := pickup_http.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		body
	)

	if error != OK:
		picking_up_item = false
		pickup_character_id = ""
		item_pickup_completed.emit(
			false,
			"Could not start item pickup request."
		)


func _on_pickup_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	picking_up_item = false

	if not CharacterManager.has_selected_character() \
	or CharacterManager.selected_character_id != pickup_character_id:
		pickup_character_id = ""
		item_pickup_completed.emit(
			false,
			"Pickup response ignored: character changed."
		)
		return

	pickup_character_id = ""

	if result != HTTPRequest.RESULT_SUCCESS:
		item_pickup_completed.emit(
			false,
			"Network error picking up item."
		)
		return

	if response_code < 200 or response_code >= 300:
		item_pickup_completed.emit(
			false,
			"Supabase error: " + body.get_string_from_utf8()
		)
		return

	var parsed: Variant = JSON.parse_string(
		body.get_string_from_utf8()
	)

	if parsed != true:
		item_pickup_completed.emit(
			false,
			"Item pickup was not confirmed by the server."
		)
		return

	item_pickup_completed.emit(
		true,
		"Item picked up successfully."
	)


func load_ground_items() -> void:
	if loading_ground_items:
		return

	if not PlayerService.is_authenticated \
	or PlayerService.access_token.is_empty():
		ground_items_loaded.emit(false, "Player is not signed in.")
		return

	if not CharacterManager.has_selected_character():
		ground_items_loaded.emit(false, "No character selected.")
		return

	loading_ground_items = true
	ground_loading_character_id = CharacterManager.selected_character_id
	ground_items.clear()

	var url := (
		PlayerService.SUPABASE_URL
		+ "/rest/v1/ground_items"
		+ "?select=item_id,character_id,world_position_x,world_position_y,world_position_z,scene_id"
		+ "&character_id=eq." + ground_loading_character_id
		+ "&scene_id=eq.Town"
	)

	var headers := PackedStringArray([
		"apikey: " + PlayerService.SUPABASE_KEY,
		"Authorization: Bearer " + PlayerService.access_token,
		"Accept: application/json"
	])

	var error := ground_http.request(
		url,
		headers,
		HTTPClient.METHOD_GET
	)

	if error != OK:
		loading_ground_items = false
		ground_loading_character_id = ""
		ground_items_loaded.emit(
			false,
			"Could not start ground-item request."
		)


func _on_ground_items_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	loading_ground_items = false

	if not CharacterManager.has_selected_character() \
	or CharacterManager.selected_character_id != ground_loading_character_id:
		ground_loading_character_id = ""
		ground_items.clear()
		ground_items_loaded.emit(
			false,
			"Ground-item request cancelled: character changed."
		)
		return

	ground_loading_character_id = ""

	if result != HTTPRequest.RESULT_SUCCESS:
		ground_items_loaded.emit(
			false,
			"Network error loading ground items."
		)
		return

	if response_code < 200 or response_code >= 300:
		ground_items_loaded.emit(
			false,
			"Supabase error: " + body.get_string_from_utf8()
		)
		return

	var parsed: Variant = JSON.parse_string(
		body.get_string_from_utf8()
	)

	if not parsed is Array:
		ground_items_loaded.emit(
			false,
			"Unexpected ground-item response."
		)
		return

	ground_items.clear()

	for entry in parsed:
		if entry is Dictionary:
			ground_items.append(entry)

	ground_items_loaded.emit(
		true,
		"Ground items loaded successfully."
	)
