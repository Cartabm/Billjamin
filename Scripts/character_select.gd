
extends Control

@onready var archer_button: Button = $CenterContainer/VBoxContainer/ArcherButton
@onready var rogue_button: Button = $CenterContainer/VBoxContainer/RogueButton
@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton
@onready var saved_characters_list: VBoxContainer = $CenterContainer/VBoxContainer/SavedCharactersList

@onready var delete_button: Button = $DeleteCharacterButton
@onready var delete_dialog: ConfirmationDialog = $DeleteCharacterDialog
@onready var delete_character_list: OptionButton = $DeleteCharacterDialog/DeleteContent/CharacterList
@onready var delete_confirm_input: LineEdit = $DeleteCharacterDialog/DeleteContent/ConfirmInput

@onready var character_name_dialog: ConfirmationDialog = $CharacterNameDialog
@onready var character_name_input: LineEdit = $CharacterNameDialog/NameContent/CharacterNameInput

var pending_character_class: String = ""

var deletion_in_progress: bool = false


func _ready() -> void:
	CharacterManager.clear_selected_character()
	InventoryManager.items.clear()

	archer_button.pressed.connect(_on_archer_pressed)
	rogue_button.pressed.connect(_on_rogue_pressed)
	back_button.pressed.connect(_on_back_pressed)

	CharacterDatabase.characters_loaded.connect(_on_characters_loaded)
	CharacterDatabase.character_created.connect(_on_character_created)
	CharacterDatabase.character_deleted.connect(_on_character_deleted)

	character_name_dialog.confirmed.connect(_on_character_name_confirmed)
	character_name_dialog.canceled.connect(_on_character_name_canceled)
	character_name_dialog.ok_button_text = "Create Character"
	character_name_input.max_length = 20
	character_name_input.text_submitted.connect(_on_character_name_submitted)

	# Delete Character interface
	delete_button.pressed.connect(_open_delete_dialog)
	delete_character_list.item_selected.connect(_on_delete_character_selected)
	delete_confirm_input.text_changed.connect(_on_delete_confirmation_changed)
	delete_dialog.confirmed.connect(_on_delete_confirmed)

	delete_dialog.ok_button_text = "Permanently Delete"
	delete_dialog.get_ok_button().disabled = true

	if PlayerService.is_authenticated:
		CharacterDatabase.load_characters()
	else:
		print("CHARACTER TEST: Skipped because player is not authenticated.")


func _on_characters_loaded(success: bool, message: String) -> void:
	print("CHARACTER DATABASE: ", success, " - ", message)
	print("CHARACTERS FOUND: ", CharacterDatabase.characters.size())

	if not success:
		push_warning("Character loading failed: " + message)
		return

	for child in saved_characters_list.get_children():
		child.queue_free()

	for character_data in CharacterDatabase.characters:
		var character_button: Button = Button.new()

		var display_name: String = str(
			character_data.get("character_name", "Unnamed")
		)

		var display_class: String = str(
			character_data.get("class_id", "unknown")
		).capitalize()

		character_button.text = "%s (%s)" % [
			display_name,
			display_class
		]

		saved_characters_list.add_child(character_button)

		character_button.pressed.connect(
			_on_saved_character_pressed.bind(character_data)
		)


func _on_archer_pressed() -> void:
	_open_character_name_dialog("archer")


func _on_rogue_pressed() -> void:
	_open_character_name_dialog("rogue")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")


func _on_character_created(
	success: bool,
	message: String,
	character: Dictionary
) -> void:
	print("CHARACTER CREATE: ", success, " - ", message)

	if not success:
		archer_button.disabled = false
		rogue_button.disabled = false

		if "23505" in message or "duplicate" in message.to_lower():
			message = "That character name is already taken."

		push_warning("Character creation failed: " + message)

		_open_character_name_dialog(pending_character_class)
		return

	CharacterManager.select_character(character)

	print("NEW CHARACTER NAME: ", CharacterManager.selected_character_name)
	print("NEW CHARACTER UUID: ", CharacterManager.selected_character_id)

	InventoryManager.load_inventory()

	var result: Array = await InventoryManager.inventory_loaded
	var inventory_success: bool = result[0]
	var inventory_message: String = result[1]

	if not inventory_success:
		archer_button.disabled = false
		rogue_button.disabled = false
		push_warning("Inventory loading failed: " + inventory_message)
		return

	print(
		"NEW CHARACTER INVENTORY LOADED: ",
		InventoryManager.items.size(),
		" items"
	)

	get_tree().change_scene_to_file("res://Scenes/Town.tscn")


func _on_saved_character_pressed(character_data: Dictionary) -> void:
	CharacterManager.select_character(character_data)

	print("PLAYING CHARACTER: ", CharacterManager.selected_character_name)
	print("CHARACTER UUID: ", CharacterManager.selected_character_id)

	InventoryManager.load_inventory()

	var result: Array = await InventoryManager.inventory_loaded
	var success: bool = result[0]
	var message: String = result[1]

	if not success:
		push_warning("Inventory loading failed: " + message)
		return

	print("INVENTORY LOADED: ", InventoryManager.items.size(), " items")

	get_tree().change_scene_to_file("res://Scenes/Town.tscn")


func _open_delete_dialog() -> void:
	if deletion_in_progress:
		return

	delete_character_list.clear()
	delete_confirm_input.clear()

	for character_data in CharacterDatabase.characters:
		var display_name: String = str(
			character_data.get("character_name", "Unnamed")
		)

		var display_class: String = str(
			character_data.get("class_id", "unknown")
		).capitalize()

		delete_character_list.add_item(
			"%s (%s)" % [display_name, display_class]
		)

	# Require the player to explicitly choose a character.
	delete_character_list.select(-1)

	delete_dialog.get_ok_button().disabled = true
	delete_dialog.popup_centered()


func _on_delete_character_selected(_index: int) -> void:
	delete_confirm_input.clear()
	delete_dialog.get_ok_button().disabled = true


func _on_delete_confirmation_changed(new_text: String) -> void:
	delete_dialog.get_ok_button().disabled = not (
		new_text == "CONFIRM DELETE"
		and delete_character_list.selected >= 0
		and not deletion_in_progress
	)


func _on_delete_confirmed() -> void:
	if deletion_in_progress:
		return

	if delete_confirm_input.text != "CONFIRM DELETE":
		return

	var selected_index: int = delete_character_list.selected

	if selected_index < 0:
		return

	if selected_index >= CharacterDatabase.characters.size():
		return

	var character_data: Dictionary = CharacterDatabase.characters[selected_index]
	var character_id: String = str(character_data.get("id", ""))

	if character_id.is_empty():
		return

	print(
		"CHARACTER DELETE REQUEST: ",
		character_data.get("character_name", "Unknown"),
		" | UUID: ",
		character_id
	)

	deletion_in_progress = true
	delete_button.disabled = true

	CharacterDatabase.delete_character(
		character_id,
		"CONFIRM DELETE"
	)


func _on_character_deleted(success: bool, message: String) -> void:
	deletion_in_progress = false
	delete_button.disabled = false

	if not success:
		push_error("CHARACTER DELETE FAILED: " + message)
		return

	print("CHARACTER DELETED: " + message)

	CharacterManager.clear_selected_character()
	InventoryManager.items.clear()

	CharacterDatabase.load_characters()

func _open_character_name_dialog(class_id: String) -> void:
	pending_character_class = class_id
	character_name_input.clear()

	character_name_dialog.title = "Create " + class_id.capitalize()
	character_name_dialog.dialog_text = "Enter a unique character name (3–20 characters):"
	character_name_dialog.popup_centered()

	character_name_input.grab_focus()


func _on_character_name_confirmed() -> void:
	var chosen_name: String = character_name_input.text.strip_edges()

	if chosen_name.length() < 3 or chosen_name.length() > 20:
		push_warning("Character name must be 3–20 characters.")
		_open_character_name_dialog(pending_character_class)
		return

	if pending_character_class.is_empty():
		return

	archer_button.disabled = true
	rogue_button.disabled = true

	print("CREATING CHARACTER: ", chosen_name, " | Class: ", pending_character_class)

	CharacterDatabase.create_character(
		pending_character_class,
		chosen_name
	)


func _on_character_name_submitted(_text: String) -> void:
	_on_character_name_confirmed()


func _on_character_name_canceled() -> void:
	pending_character_class = ""
