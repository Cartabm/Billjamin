
extends Camera3D

@export var distance: float = 5.0
@export var min_distance: float = 14.0
@export var max_distance: float = 20.0
@export var zoom_step: float = 0.5
@export var angle_down: float = 15.0

@export var shoulder_offset: float = 0.8
@export var camera_height: float = 1.6

@export var room_rotation_duration: float = 0.75
@export var mouse_sensitivity: float = 0.2
@export var min_pitch: float = -10.0
@export var max_pitch: float = 75.0

var right_mouse_held: bool = false

var player: Node3D

# Horizontal camera orbit in degrees.
var camera_yaw: float = 0.0


var rotation_tween: Tween


func _ready() -> void:
	distance = clampf(distance, min_distance, max_distance)
	call_deferred("_find_player")

func _find_player() -> void:
	player = get_tree().current_scene.get_node_or_null("Player")

	if player != null:
		update_camera_position()

func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().current_scene.get_node_or_null("Player")

		if player == null:
			return

	update_camera_position()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			right_mouse_held = event.pressed

			if right_mouse_held:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

		elif event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				distance = clampf(
					distance - zoom_step,
					min_distance,
					max_distance
				)
				update_camera_position()

			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				distance = clampf(
					distance + zoom_step,
					min_distance,
					max_distance
				)
				update_camera_position()

	elif event is InputEventMouseMotion and right_mouse_held:
		camera_yaw -= event.relative.x * mouse_sensitivity

		angle_down += event.relative.y * mouse_sensitivity
		angle_down = clampf(angle_down, min_pitch, max_pitch)

		update_camera_position()


func update_camera_position() -> void:
	if player == null or not is_instance_valid(player):
		return

	var target := player.global_position + Vector3(0.0, camera_height, 0.0)

	var pitch := deg_to_rad(angle_down)
	var yaw := deg_to_rad(camera_yaw)

	var horizontal_distance := distance * cos(pitch)

	var backward := Vector3(
		sin(yaw),
		0.0,
		cos(yaw)
	)

	var right := Vector3(
		cos(yaw),
		0.0,
		-sin(yaw)
	)

	global_position = target + Vector3(
		backward.x * horizontal_distance,
		distance * sin(pitch),
		backward.z * horizontal_distance
	) + right * shoulder_offset

	look_at(target + Vector3(0.0, 0.2, 0.0), Vector3.UP)


func rotate_to_room_entrance(
	_entrance_direction: Vector2i
) -> void:
	pass


func rotate_camera_smoothly(target_yaw: float) -> void:
	if rotation_tween and rotation_tween.is_running():
		rotation_tween.kill()

	# Use the shortest turn, avoiding unnecessary 270-degree spins.
	var difference := wrapf(
		target_yaw - camera_yaw,
		-180.0,
		180.0
	)

	var final_yaw := camera_yaw + difference

	rotation_tween = create_tween()
	rotation_tween.set_trans(Tween.TRANS_SINE)
	rotation_tween.set_ease(Tween.EASE_IN_OUT)

	rotation_tween.tween_property(
		self,
		"camera_yaw",
		final_yaw,
		room_rotation_duration
	)
