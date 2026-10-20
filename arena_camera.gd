
extends Camera3D

@export var follow_speed: float = 8.0
@export var follow_height: float = 16.0
@export var follow_distance: float = 13.0

var player: Node3D
var camera_offset: Vector3


func _ready() -> void:
	player = get_parent().get_node_or_null("Player")

	if player != null:
		camera_offset = global_position - player.global_position


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	var target_position := player.global_position + camera_offset
	var weight := 1.0 - exp(-follow_speed * delta)

	global_position = global_position.lerp(target_position, weight)
