
extends Area3D

@onready var portal_prompt: Control = get_tree().current_scene.get_node_or_null(
	"PortalUI/PortalPrompt"
) as Control

@onready var interact_label: Label3D = $InteractLabel

var player_in_range: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	interact_label.hide()

	if portal_prompt:
		portal_prompt.hide()


func _unhandled_input(event: InputEvent) -> void:
	if not player_in_range:
		return

	if event.is_action_pressed("interact"):
		if portal_prompt:
			portal_prompt.show()

		get_viewport().set_input_as_handled()


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.name == "Player":
		player_in_range = true
		interact_label.show()


func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D and body.name == "Player":
		player_in_range = false
		interact_label.hide()

		if portal_prompt:
			portal_prompt.hide()
