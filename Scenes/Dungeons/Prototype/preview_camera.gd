
extends Camera3D

var player: Node3D


func _ready() -> void:
	player = get_tree().current_scene.find_child("Player", true, false) as Node3D

	if player == null:
		push_error("PreviewCamera: Could not find Player!")
		return

	make_current()
	update_camera_position()


func _process(_delta: float) -> void:
	if player == null:
		return

	update_camera_position()


func update_camera_position() -> void:
	global_position = player.global_position + Vector3(0.0, 25.0, 36.0)
