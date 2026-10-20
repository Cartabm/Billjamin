
extends StaticBody3D

@onready var interaction_area: Area3D = $InteractionArea
@onready var leaderboard_ui: CanvasLayer = get_tree().current_scene.get_node("LeaderboardUI")
@onready var interaction_prompt: Control = get_tree().current_scene.get_node("LeaderboardUI/InteractionPrompt")

var player_nearby: bool = false


func _ready() -> void:
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	interaction_prompt.hide()


func _process(_delta: float) -> void:
	if player_nearby and Input.is_action_just_pressed("interact"):
		leaderboard_ui.call("open_leaderboard")
		interaction_prompt.hide()


func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		player_nearby = true
		interaction_prompt.show()


func _on_body_exited(body: Node3D) -> void:
	if body.name == "Player":
		player_nearby = false
		interaction_prompt.hide()
