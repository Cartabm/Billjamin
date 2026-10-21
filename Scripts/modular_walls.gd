
extends Node3D

@export var wall_scene: PackedScene
@export var corner_scene: PackedScene

@export_group("Room Dimensions")
@export var room_width: float = 20.0
@export var room_depth: float = 20.0
@export var wall_length: float = 2.0

@export_group("Enabled Walls")
@export var north_wall: bool = true
@export var south_wall: bool = true
@export var east_wall: bool = true
@export var west_wall: bool = true

@export_group("Doorways")
@export var north_door: bool = false
@export var south_door: bool = false
@export var east_door: bool = false
@export var west_door: bool = false
@export var doorway_width: float = 4.0


func _ready() -> void:
	generate_walls()


func generate_walls() -> void:
	if wall_scene == null:
		push_error("ModularWalls: StoneWall.tscn is not assigned!")
		return

	_clear_generated_walls()

	var width_count: int = roundi(room_width / wall_length)
	var depth_count: int = roundi(room_depth / wall_length)

	var half_width: float = room_width / 2.0
	var half_depth: float = room_depth / 2.0

	# North and south walls.
	for i in range(width_count):
		var offset: float = -half_width + wall_length * (i + 0.5)

		if north_wall:
			if not north_door or absf(offset) >= doorway_width / 2.0:
				_add_piece(
					wall_scene,
					Vector3(offset, 0.0, -half_depth),
					0.0
				)

		if south_wall:
			if not south_door or absf(offset) >= doorway_width / 2.0:
				_add_piece(
					wall_scene,
					Vector3(offset, 0.0, half_depth),
					0.0
				)

	# East and west walls.
	for i in range(depth_count):
		var offset: float = -half_depth + wall_length * (i + 0.5)

		if west_wall:
			if not west_door or absf(offset) >= doorway_width / 2.0:
				_add_piece(
					wall_scene,
					Vector3(-half_width, 0.0, offset),
					90.0
				)

		if east_wall:
			if not east_door or absf(offset) >= doorway_width / 2.0:
				_add_piece(
					wall_scene,
					Vector3(half_width, 0.0, offset),
					90.0
				)

	# Corner pillars.
	if corner_scene != null:
		if north_wall and west_wall:
			_add_piece(
				corner_scene,
				Vector3(-half_width, 0.0, -half_depth),
				0.0
			)

		if north_wall and east_wall:
			_add_piece(
				corner_scene,
				Vector3(half_width, 0.0, -half_depth),
				0.0
			)

		if south_wall and west_wall:
			_add_piece(
				corner_scene,
				Vector3(-half_width, 0.0, half_depth),
				0.0
			)

		if south_wall and east_wall:
			_add_piece(
				corner_scene,
				Vector3(half_width, 0.0, half_depth),
				0.0
			)


func _clear_generated_walls() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()


func _add_piece(scene: PackedScene, pos: Vector3, angle: float) -> void:
	var piece := scene.instantiate() as Node3D

	if piece == null:
		push_error("ModularWalls: Could not instantiate environment piece.")
		return

	add_child(piece)
	piece.position = pos
	piece.rotation_degrees.y = angle
