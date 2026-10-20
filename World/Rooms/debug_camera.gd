
extends Camera3D

@export var move_speed: float = 45.0
@export var rotate_speed: float = 90.0
@export var zoom_speed: float = 60.0
@export var mouse_sensitivity: float = 0.2

var right_mouse_held: bool = true

@export var follow_player: bool = true
@export var camera_offset: Vector3 = Vector3(0, 35, 25)

@onready var player: Node3D = get_parent().get_node_or_null("Player")

	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			right_mouse_held = event.pressed

			if right_mouse_held:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseMotion and right_mouse_held:
		rotation_degrees.y -= event.relative.x * mouse_sensitivity
		rotation_degrees.x -= event.relative.y * mouse_sensitivity

		# Prevent the camera from flipping upside down.
		rotation_degrees.x = clampf(
			rotation_degrees.x,
			-89.0,
			-5.0
		)


func _process(delta: float) -> void:
	var movement := Vector3.ZERO

	if follow_player and is_instance_valid(player):
		global_position = player.global_position + camera_offset
	
	if Input.is_key_pressed(KEY_W):
		movement.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		movement.z += 1.0
	if Input.is_key_pressed(KEY_A):
		movement.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		movement.x += 1.0

	if movement.length() > 0.0:
		movement = movement.normalized()
		global_position += movement * move_speed * delta

	if Input.is_key_pressed(KEY_Q):
		rotation_degrees.y += rotate_speed * delta
	if Input.is_key_pressed(KEY_E):
		rotation_degrees.y -= rotate_speed * delta

	if Input.is_key_pressed(KEY_R):
		position.y += move_speed * delta
	if Input.is_key_pressed(KEY_F):
		position.y -= move_speed * delta

	if Input.is_key_pressed(KEY_Z):
		size = maxf(10.0, size - zoom_speed * delta)
	if Input.is_key_pressed(KEY_X):
		size += zoom_speed * delta


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
