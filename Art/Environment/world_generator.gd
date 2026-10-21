extends Node3D

@export var floor_scene: PackedScene
@export var wall_scene: PackedScene
@export var corner_scene: PackedScene
@export_group("Dungeon Exit")
@export var exit_portal_scene: PackedScene

@export_group("Solid Exterior")
@export var generate_solid_exterior: bool = true
@export var exterior_texture: Texture2D
@export_range(2.0, 30.0, 1.0) var exterior_margin: float = 12.0
@export_range(1.0, 15.0, 0.5) var exterior_height: float = 6.0
@export_range(0.1, 4.0, 0.1) var exterior_tile_size: float = 2.0

const FLOOR_SIZE: float = 20.0
const FLOOR_THICKNESS: float = 0.2
const WALL_LENGTH: float = 2.0

# World-space room rectangles: center and dimensions.
const AREAS := [
	{"center": Vector2(0.0, 0.0), "size": Vector2(20.0, 20.0), "name": "StartRoom"},
	{"center": Vector2(0.0, -16.0), "size": Vector2(4.0, 12.0), "name": "Corridor"},
	{"center": Vector2(0.0, -37.0), "size": Vector2(30.0, 30.0), "name": "OpenArea"}
]


func _ready() -> void:
	generate_world()


func generate_world() -> void:
	if floor_scene == null or wall_scene == null:
		push_error("WorldGenerator: Assign FloorTile and StoneWall scenes.")
		return

	for child in get_children():
		remove_child(child)
		child.queue_free()

	for data in AREAS:
		_generate_area(data["center"], data["size"], data["name"])

	if generate_solid_exterior:
		_create_solid_exterior()
		_spawn_exit_portal()


func _generate_area(center: Vector2, dimensions: Vector2, area_name: String) -> void:
	var area := Node3D.new()
	area.name = area_name
	add_child(area)
	area.position = Vector3(center.x, 0.0, center.y)

	_create_floor(area, dimensions)
	_create_walls(area, dimensions, area_name)


func _create_floor(parent: Node3D, dimensions: Vector2) -> void:
	var source_floor := floor_scene.instantiate() as Node3D
	if source_floor == null:
		push_error("WorldGenerator: Floor scene could not be loaded.")
		return

	var source_mesh: MeshInstance3D = null
	if source_floor is MeshInstance3D:
		source_mesh = source_floor as MeshInstance3D
	else:
		source_mesh = source_floor.find_child("*", true, false) as MeshInstance3D

	if source_mesh == null:
		push_error("WorldGenerator: Floor mesh not found.")
		source_floor.free()
		return

	var source_material: Material = source_mesh.get_active_material(0)
	if source_material == null:
		push_error("WorldGenerator: Floor material not found.")
		source_floor.free()
		return

	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	parent.add_child(floor_body)

	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "FloorMesh"
	var box := BoxMesh.new()
	box.size = Vector3(dimensions.x, FLOOR_THICKNESS, dimensions.y)
	floor_mesh.mesh = box
	floor_body.add_child(floor_mesh)

	var material := source_material.duplicate() as Material
	if material is StandardMaterial3D:
		var stone_material := material as StandardMaterial3D
		stone_material.uv1_scale = Vector3(
			10.0 * dimensions.x / FLOOR_SIZE,
			10.0 * dimensions.y / FLOOR_SIZE,
			10.0
		)
		stone_material.texture_repeat = true
		stone_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	floor_mesh.set_surface_override_material(0, material)

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(dimensions.x, FLOOR_THICKNESS, dimensions.y)
	collision.shape = shape
	floor_body.add_child(collision)
	floor_body.position.y = -FLOOR_THICKNESS / 2.0
	source_floor.free()


func _create_walls(parent: Node3D, dimensions: Vector2, area_name: String) -> void:
	var half_x: float = dimensions.x / 2.0
	var half_z: float = dimensions.y / 2.0
	var count_x: int = roundi(dimensions.x / WALL_LENGTH)
	var count_z: int = roundi(dimensions.y / WALL_LENGTH)
	var north_open: bool = area_name == "StartRoom" or area_name == "Corridor"
	var south_open: bool = area_name == "Corridor" or area_name == "OpenArea"

	for i in range(count_x):
		var x: float = -half_x + WALL_LENGTH * (i + 0.5)
		if not north_open or absf(x) >= 2.0:
			_add_wall(parent, Vector3(x, 0.0, -half_z), 0.0)
		if not south_open or absf(x) >= 2.0:
			_add_wall(parent, Vector3(x, 0.0, half_z), 0.0)

	for i in range(count_z):
		var z: float = -half_z + WALL_LENGTH * (i + 0.5)
		_add_wall(parent, Vector3(-half_x, 0.0, z), 90.0)
		_add_wall(parent, Vector3(half_x, 0.0, z), 90.0)

	if corner_scene != null:
		_add_corner(parent, Vector3(-half_x, 0.0, -half_z))
		_add_corner(parent, Vector3(half_x, 0.0, -half_z))
		_add_corner(parent, Vector3(-half_x, 0.0, half_z))
		_add_corner(parent, Vector3(half_x, 0.0, half_z))


func _add_wall(parent: Node3D, pos: Vector3, angle: float) -> void:
	var wall := wall_scene.instantiate() as Node3D
	if wall == null:
		return
	parent.add_child(wall)
	wall.position = pos
	wall.rotation_degrees.y = angle


func _add_corner(parent: Node3D, pos: Vector3) -> void:
	var corner := corner_scene.instantiate() as Node3D
	if corner == null:
		return
	parent.add_child(corner)
	corner.position = pos


func _inside_dungeon(x: float, z: float) -> bool:
	for data in AREAS:
		var center: Vector2 = data["center"]
		var dimensions: Vector2 = data["size"]
		if absf(x - center.x) < dimensions.x * 0.5 and absf(z - center.y) < dimensions.y * 0.5:
			return true
	return false


func _create_solid_exterior() -> void:
	# Tile-aligned blocks surround, but never occupy, the walkable footprint.
	# A one-unit grid keeps boundaries flush with 15-unit room edges.
	var min_x: float = -15.0 - exterior_margin
	var max_x: float = 15.0 + exterior_margin
	var min_z: float = -52.0 - exterior_margin
	var max_z: float = 10.0 + exterior_margin
	var step: float = 1.0
	var start_x: int = floori(min_x / step)
	var end_x: int = ceili(max_x / step)
	var start_z: int = floori(min_z / step)
	var end_z: int = ceili(max_z / step)

	var exterior := Node3D.new()
	exterior.name = "SolidExterior"
	add_child(exterior)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.20, 0.22, 0.23)
	material.roughness = 1.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.texture_repeat = true
	if exterior_texture != null:
		material.albedo_texture = exterior_texture
	material.uv1_scale = Vector3(step / exterior_tile_size, step / exterior_tile_size, 1.0)

	# Combine all exterior top faces into one mesh for efficient rendering.
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var top_y: float = exterior_height

	for ix in range(start_x, end_x):
		for iz in range(start_z, end_z):
			var x0: float = float(ix) * step
			var z0: float = float(iz) * step
			var x1: float = x0 + step
			var z1: float = z0 + step
			var cx: float = (x0 + x1) * 0.5
			var cz: float = (z0 + z1) * 0.5
			if _inside_dungeon(cx, cz):
				continue

			var base: int = vertices.size()
			vertices.append_array(PackedVector3Array([
				Vector3(x0, top_y, z0), Vector3(x0, top_y, z1),
				Vector3(x1, top_y, z1), Vector3(x1, top_y, z0)
			]))
			for j in range(4):
				normals.append(Vector3.UP)
			uvs.append_array(PackedVector2Array([
				Vector2(x0 / exterior_tile_size, z0 / exterior_tile_size),
				Vector2(x0 / exterior_tile_size, z1 / exterior_tile_size),
				Vector2(x1 / exterior_tile_size, z1 / exterior_tile_size),
				Vector2(x1 / exterior_tile_size, z0 / exterior_tile_size)
			]))
			indices.append_array(PackedInt32Array([
				base, base + 2, base + 1,
				base, base + 3, base + 2
			]))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "RockSurface"
	mesh_instance.mesh = mesh
	exterior.add_child(mesh_instance)



func _spawn_exit_portal() -> void:
	if exit_portal_scene == null:
		push_warning("WorldGenerator: Exit Portal Scene is not assigned.")
		return

	# Choose one of the two rooms, excluding the corridor.
	var room_names: Array[String] = ["StartRoom", "OpenArea"]
	var chosen_name: String = room_names.pick_random()

	var chosen_room: Node3D = get_node_or_null(chosen_name) as Node3D

	if chosen_room == null:
		push_warning("WorldGenerator: Could not find room " + chosen_name)
		return

	var portal := exit_portal_scene.instantiate() as Node3D

	if portal == null:
		push_error("WorldGenerator: Could not instantiate exit portal.")
		return

	chosen_room.add_child(portal)

	# Position relative to the center of the selected room.
	portal.position = Vector3(0.0, 0.05, 0.0)

	print("Exit portal spawned in: ", chosen_name)
