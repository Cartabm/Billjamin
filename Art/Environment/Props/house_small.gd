
extends Node3D

@onready var door_interaction: Area3D = $DoorInteraction
@onready var interaction_prompt: Label3D = $InteractionPrompt
@onready var prompt_background: Sprite3D = $PromptBackground

var player_near_door: bool = false


func _ready() -> void:
	# Hide both popup elements when the scene starts.
	interaction_prompt.hide()
	prompt_background.hide()

	# Connect signals only if they aren't already connected.
	if not door_interaction.body_entered.is_connected(_on_body_entered):
		door_interaction.body_entered.connect(_on_body_entered)

	if not door_interaction.body_exited.is_connected(_on_body_exited):
		door_interaction.body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if not player_near_door:
		return

	if event.is_action_pressed("interact") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_enter_dungeon()


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.name == "TestPlayer":
		player_near_door = true

		interaction_prompt.show()
		prompt_background.show()

		print("Press E to enter dungeon")


func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D and body.name == "TestPlayer":
		player_near_door = false

		interaction_prompt.hide()
		prompt_background.hide()




func _enter_dungeon() -> void:
	print("Entering dungeon...")

	# Find the marker outside the house door.
	var entrance: Marker3D = $DungeonEntrance

	# Save a position a short distance outside the door.
	var return_pos: Vector3 = entrance.global_position
	return_pos += global_transform.basis.z.normalized() * 1.5
	return_pos.y += 0.5

	# Save the location BEFORE changing scenes.
	DungeonReturnState.remember_entrance(return_pos)

	print("Saved house return position: ", return_pos)
	print("Return point saved: ", DungeonReturnState.has_return_point)

	# Enter the dungeon.
	get_tree().call_deferred(
		"change_scene_to_file",
		"res://Art/Environment/WorldTest.tscn"
	)
