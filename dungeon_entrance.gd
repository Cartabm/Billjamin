
extends StaticBody3D

@export_file("*.tscn") var dungeon_scene_path: String = "res://Game.tscn"

@onready var interaction_area: Area3D = $InteractionArea

var player_nearby: bool = false


func _ready() -> void:
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		player_nearby = true
		print("Press E to enter the dungeon")


func _on_body_exited(body: Node3D) -> void:
	if body.name == "Player":
		player_nearby = false


func _unhandled_input(event: InputEvent) -> void:
	if not player_nearby:
		return

	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_E:
			get_viewport().set_input_as_handled()
			enter_dungeon()


func enter_dungeon() -> void:
	get_tree().paused = false

	if not ResourceLoader.exists(dungeon_scene_path):
		push_error("Dungeon scene not found: " + dungeon_scene_path)
		return

	get_tree().change_scene_to_file(dungeon_scene_path)
