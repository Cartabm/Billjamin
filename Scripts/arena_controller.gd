
extends Node3D

@export var arena_size: float = 200.0
@export var wall_height: float = 2.0
@export var wall_thickness: float = 0.5
@export var floor_thickness: float = 0.5

func _enter_tree() -> void:
	if not CharacterManager.has_selected_character():
		push_warning("Game: No character selected.")
		return

	var player_scene: PackedScene = CharacterManager.get_selected_player_scene()

	if player_scene == null:
		push_error("Game: Selected player scene not found.")
		return

	var old_player := get_node_or_null("Player")
	var spawn_transform := Transform3D.IDENTITY

	if old_player != null:
		remove_child(old_player)
		old_player.queue_free()

	var player := player_scene.instantiate() as CharacterBody3D

	if player == null:
		push_error("Game: Player scene must have a CharacterBody3D root.")
		return

	player.name = "Player"

	player.transform = spawn_transform

	add_child(player)

	print("GAME PLAYER SPAWNED: ", CharacterManager.selected_character_name)

func _ready() -> void:
	update_arena()


func update_arena() -> void:
	var half_size: float = arena_size / 2.0

	# Resize floor mesh and collision.
	var ground_mesh = get_node_or_null("Ground/MeshInstance3D")
	if ground_mesh != null and ground_mesh.mesh is BoxMesh:
		ground_mesh.mesh.size = Vector3(arena_size, floor_thickness, arena_size)
		ground_mesh.position = Vector3(0, -floor_thickness / 2.0, 0)

	var ground_collision = get_node_or_null("Ground/CollisionShape3D")
	if ground_collision != null and ground_collision.shape is BoxShape3D:
		ground_collision.shape.size = Vector3(arena_size, floor_thickness, arena_size)
		ground_collision.position = Vector3(0, -floor_thickness / 2.0, 0)

	# North and south: long side runs along X.
	set_wall(
		"WallNorth",
		Vector3(0, wall_height / 2.0, -half_size + wall_thickness / 2.0),
		Vector3(arena_size, wall_height, wall_thickness),
		0.0
	)

	set_wall(
		"WallSouth",
		Vector3(0, wall_height / 2.0, half_size - wall_thickness / 2.0),
		Vector3(arena_size, wall_height, wall_thickness),
		0.0
	)

	# East and west: long side runs along Z.
	set_wall(
		"WallEast",
		Vector3(half_size - wall_thickness / 2.0, wall_height / 2.0, 0),
		Vector3(wall_thickness, wall_height, arena_size),
		0.0
	)

	set_wall(
		"WallWest",
		Vector3(-half_size + wall_thickness / 2.0, wall_height / 2.0, 0),
		Vector3(wall_thickness, wall_height, arena_size),
		0.0
	)



func set_wall(
	wall_name: String,
	wall_position: Vector3,
	wall_size: Vector3,
	wall_rotation_y: float
) -> void:
	var wall = get_node_or_null(wall_name)

	if wall == null:
		push_warning("Arena wall not found: " + wall_name)
		return

	wall.position = wall_position
	wall.rotation = Vector3(0, deg_to_rad(wall_rotation_y), 0)

	var wall_mesh = wall.get_node_or_null("MeshInstance3D")
	if wall_mesh != null:
		wall_mesh.position = Vector3.ZERO
		wall_mesh.rotation = Vector3.ZERO

		if wall_mesh.mesh is BoxMesh:
			# Make this wall's mesh independent of other walls.
			wall_mesh.mesh = wall_mesh.mesh.duplicate()
			wall_mesh.mesh.size = wall_size

	var wall_collision = wall.get_node_or_null("CollisionShape3D")
	if wall_collision != null:
		wall_collision.position = Vector3.ZERO
		wall_collision.rotation = Vector3.ZERO

		if wall_collision.shape is BoxShape3D:
			# Make this wall's collision independent of other walls.
			wall_collision.shape = wall_collision.shape.duplicate()
			wall_collision.shape.size = wall_size
