extends Camera3D

@export_group("Zoom Settings")
@export var zoom_speed: float = 2.0
@export var min_zoom: float = 5.0
@export var max_zoom: float = 35.0

@export_group("Follow Settings")
@export var follow_target: Node3D
@export var follow_speed: float = 8.0

var camera_offset: Vector3


func _ready() -> void:
	# Automatically find the character spawned by CharacterManager.
	follow_target = get_parent().get_node_or_null("Player") as Node3D

	if follow_target == null:
		push_warning("TestCamera: Player not found.")
		return

	camera_offset = global_position - follow_target.global_position

	print("TestCamera following: ", follow_target.name)


func _process(delta: float) -> void:
	if not is_instance_valid(follow_target):
		return

	var target_position := follow_target.global_position + camera_offset

	global_position = global_position.lerp(
		target_position,
		clampf(follow_speed * delta, 0.0, 1.0)
	)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			size = clampf(size - zoom_speed, min_zoom, max_zoom)

		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			size = clampf(size + zoom_speed, min_zoom, max_zoom)
