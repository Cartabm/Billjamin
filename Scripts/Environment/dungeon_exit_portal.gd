
extends Node3D

@onready var interaction_area: Area3D = $InteractionArea
@onready var interaction_prompt: Label3D = $InteractionPrompt

var player_near_portal: bool = false
var is_exiting: bool = false


func _ready() -> void:
	interaction_prompt.hide()

	if not interaction_area.body_entered.is_connected(_on_body_entered):
		interaction_area.body_entered.connect(_on_body_entered)

	if not interaction_area.body_exited.is_connected(_on_body_exited):
		interaction_area.body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if not player_near_portal:
		return

	if is_exiting:
		return

	if event.is_action_pressed("interact") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_exit_dungeon()


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.name == "TestPlayer":
		player_near_portal = true
		interaction_prompt.show()
		print("Player entered exit portal area")


func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D and body.name == "TestPlayer":
		player_near_portal = false
		interaction_prompt.hide()


func _exit_dungeon() -> void:
	if is_exiting:
		return

	if not DungeonReturnState.has_return_point:
		push_warning(
			"No saved return point. Enter the dungeon through a house first."
		)
		return

	is_exiting = true
	interaction_prompt.hide()

	print("Exit portal activated! Returning to overworld...")

	DungeonReturnState.return_to_overworld()
