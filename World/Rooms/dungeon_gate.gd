
extends Node3D

@export var gate_width: float = 4.0
@export var gate_height: float = 5.0
@export var drop_duration: float = 0.7

var gate_body: AnimatableBody3D
var motion_tween: Tween
var is_closed: bool = false


func _ready() -> void:
	_build_gate()

	# Gates start raised, invisible, and non-collidable.
	gate_body.position.y = gate_height + 0.6
	gate_body.collision_layer = 0
	gate_body.collision_mask = 0
	gate_body.visible = false


func close_gate() -> void:
	if is_closed:
		return

	is_closed = true

	# Make the gate visible before it drops.
	gate_body.visible = true

	_animate_to(0.0)


func open_gate() -> void:
	if not is_closed:
		return

	is_closed = false

	# Remove collision before raising the gate.
	gate_body.collision_layer = 0
	gate_body.collision_mask = 0

	_animate_to(gate_height + 0.6)


func _animate_to(target_y: float) -> void:
	if motion_tween and motion_tween.is_running():
		motion_tween.kill()

	motion_tween = create_tween()
	motion_tween.set_trans(Tween.TRANS_QUAD)
	motion_tween.set_ease(
		Tween.EASE_IN if is_closed else Tween.EASE_OUT
	)

	motion_tween.tween_property(
		gate_body,
		"position:y",
		target_y,
		drop_duration
	)

	if is_closed:
		motion_tween.tween_callback(_enable_closed_collision)
	else:
		# Hide only after the gate has finished rising.
		motion_tween.tween_callback(_hide_open_gate)


func _enable_closed_collision() -> void:
	if not is_closed:
		return

	gate_body.collision_layer = 1
	gate_body.collision_mask = 1


func _hide_open_gate() -> void:
	if is_closed:
		return

	gate_body.visible = false


func _build_gate() -> void:
	gate_body = AnimatableBody3D.new()
	gate_body.name = "GateBody"
	gate_body.sync_to_physics = false
	gate_body.collision_layer = 0
	gate_body.collision_mask = 0
	add_child(gate_body)

	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.17, 0.19, 0.21)
	iron.metallic = 0.85
	iron.roughness = 0.35

	var bar_count := 7

	for i in range(bar_count):
		var x := (
			-gate_width * 0.5
			+ 0.25
			+ float(i) * (gate_width - 0.5)
			/ float(bar_count - 1)
		)

		_add_piece(
			"VerticalBar_%d" % i,
			Vector3(0.17, gate_height, 0.20),
			Vector3(x, gate_height * 0.5, 0.0),
			iron
		)

	for y in [0.35, gate_height * 0.5, gate_height - 0.25]:
		_add_piece(
			"CrossRail",
			Vector3(gate_width, 0.23, 0.28),
			Vector3(0.0, y, 0.0),
			iron
		)


func _add_piece(
	piece_name: String,
	size: Vector3,
	offset: Vector3,
	material: Material
) -> void:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = piece_name

	var mesh := BoxMesh.new()
	mesh.size = size

	mesh_node.mesh = mesh
	mesh_node.material_override = material
	mesh_node.position = offset
	gate_body.add_child(mesh_node)

	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size

	collider.shape = shape
	collider.position = offset
	gate_body.add_child(collider)
