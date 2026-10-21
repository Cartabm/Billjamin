extends Node3D

@export_group("World Settings")
@export var world_seed: int = 12345
@export var chunk_size: float = 20.0
@export_range(1, 5, 1) var render_distance: int = 2

@export_group("Terrain Settings")
@export_range(0.5, 5.0, 0.5) var terrain_cell_size: float = 2.0
@export var biome_frequency: float = 0.025

@export_group("Hills")
@export var hills_enabled: bool = true
@export_range(0.001, 0.05, 0.001) var hill_frequency: float = 0.008
@export_range(0.0, 12.0, 0.5) var hill_height: float = 5.0
@export_range(0.0, 1.0, 0.05) var hill_threshold: float = 0.15
@export_range(0.0, 1.0, 0.05) var hilltop_flatness: float = 0.65
@export_range(0.0, 20.0, 0.5) var start_flat_radius: float = 9.0
@export_range(0.5, 20.0, 0.5) var start_blend_width: float = 8.0

@export_group("References")
@export var player: Node3D

@export_group("Terrain Textures")
@export var grass_texture: Texture2D
@export var dirt_texture: Texture2D
@export var stone_texture: Texture2D

@export_group("Trees")
@export var oak_tree_scene: PackedScene
@export_range(0.0, 1.0, 0.01) var tree_density: float = 0.35
@export_range(2.0, 12.0, 0.5) var tree_spacing: float = 5.0
@export_range(0.0, 20.0, 0.5) var spawn_clear_radius: float = 9.0
@export var forest_frequency: float = 0.012

@export_group("Procedural Houses")
@export var house_scene: PackedScene
@export_range(0.0, 1.0, 0.05) var house_chance: float = 0.75
@export_range(30.0, 120.0, 5.0) var house_spacing: float = 60.0
@export_range(0.0, 12.0, 0.5) var house_min_hill_height: float = 1.0
@export_range(4.0, 12.0, 0.5) var house_plot_radius: float = 5.5
@export_range(1.0, 8.0, 0.5) var house_plot_blend: float = 3.0
@export_range(10.0, 40.0, 1.0) var house_spawn_clear_radius: float = 22.0

const FLOOR_THICKNESS: float = 0.2
const TEXTURE_REPEATS_PER_UNIT: float = 0.5

var loaded_chunks: Dictionary = {}
var current_chunk: Vector2i = Vector2i.ZERO
var starting_position: Vector3

var world_noise := FastNoiseLite.new()
var forest_noise := FastNoiseLite.new()
var hill_noise := FastNoiseLite.new()
var terrain_materials: Array[StandardMaterial3D] = []
var house_cache: Dictionary = {}


func _ready() -> void:
	if player == null:
		push_error("OverworldGenerator: Assign the Player.")
		set_process(false)
		return

	if grass_texture == null or dirt_texture == null or stone_texture == null:
		push_error("OverworldGenerator: Assign all three terrain textures.")
		set_process(false)
		return

	# Keep the initial spawn clearing fixed when returning from a dungeon.
	# The saved return position is applied after this scene begins loading.
	starting_position = player.global_position
	house_cache.clear()

	world_noise.seed = world_seed
	world_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	world_noise.frequency = biome_frequency
	world_noise.fractal_type = FastNoiseLite.FRACTAL_FBM

	forest_noise.seed = world_seed + 9173
	forest_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	forest_noise.frequency = forest_frequency
	forest_noise.fractal_type = FastNoiseLite.FRACTAL_FBM

	hill_noise.seed = world_seed + 23117
	hill_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	hill_noise.frequency = hill_frequency
	hill_noise.fractal_type = FastNoiseLite.FRACTAL_FBM

	terrain_materials.clear()
	terrain_materials.append(_make_material(grass_texture))
	terrain_materials.append(_make_material(dirt_texture))
	terrain_materials.append(_make_material(stone_texture))

	current_chunk = _get_chunk_coordinate(player.global_position)
	_update_chunks()


func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return

	var new_chunk := _get_chunk_coordinate(player.global_position)

	if new_chunk != current_chunk:
		current_chunk = new_chunk
		_update_chunks()


func _make_material(texture: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.texture_repeat = true
	material.roughness = 1.0
	return material


func _get_chunk_coordinate(world_position: Vector3) -> Vector2i:
	return Vector2i(
		floori(world_position.x / chunk_size),
		floori(world_position.z / chunk_size)
	)


func _update_chunks() -> void:
	var needed_chunks: Dictionary = {}

	for x in range(
		current_chunk.x - render_distance,
		current_chunk.x + render_distance + 1
	):
		for z in range(
			current_chunk.y - render_distance,
			current_chunk.y + render_distance + 1
		):
			var coord := Vector2i(x, z)
			needed_chunks[coord] = true

			if not loaded_chunks.has(coord):
				_generate_chunk(coord)

	for coord in loaded_chunks.keys():
		if not needed_chunks.has(coord):
			var chunk: Node3D = loaded_chunks[coord]
			loaded_chunks.erase(coord)
			chunk.queue_free()


func _generate_chunk(coord: Vector2i) -> void:
	var chunk := Node3D.new()
	chunk.name = "Chunk_%d_%d" % [coord.x, coord.y]
	add_child(chunk)

	chunk.position = Vector3(
		float(coord.x) * chunk_size,
		0.0,
		float(coord.y) * chunk_size
	)

	_create_terrain_mesh(chunk, coord)
	_create_chunk_trees(chunk, coord)
	_create_chunk_houses(chunk, coord)

	loaded_chunks[coord] = chunk


func _get_terrain_type(world_x: float, world_z: float) -> int:
	var value := world_noise.get_noise_2d(world_x, world_z)

	if value < -0.18:
		return 1  # Dirt

	if value > 0.18:
		return 2  # Stone

	return 0  # Grass


func _get_height(world_x: float, world_z: float) -> float:
	var original: float = _get_natural_height(world_x, world_z)
	if house_scene == null or house_chance <= 0.0:
		return original

	var position_2d := Vector2(world_x, world_z)
	var cell_x: int = floori(world_x / house_spacing)
	var cell_z: int = floori(world_z / house_spacing)
	var outer_radius: float = house_plot_radius + house_plot_blend

	# Check adjacent grid cells so flattened plots cross chunk borders seamlessly.
	for gx in range(cell_x - 1, cell_x + 2):
		for gz in range(cell_z - 1, cell_z + 2):
			var house_data: Dictionary = _get_house_data(gx, gz)
			if house_data.is_empty():
				continue
			var center: Vector2 = house_data["center"]
			var distance: float = position_2d.distance_to(center)
			if distance >= outer_radius:
				continue
			var target_height: float = house_data["height"]
			if distance <= house_plot_radius:
				return target_height
			var t: float = (distance - house_plot_radius) / maxf(0.01, house_plot_blend)
			t = t * t * (3.0 - 2.0 * t)
			return lerpf(target_height, original, t)
	return original


func _get_natural_height(world_x: float, world_z: float) -> float:
	if not hills_enabled or hill_height <= 0.0:
		return 0.0

	var noise_value: float = hill_noise.get_noise_2d(world_x, world_z)
	var t: float = clampf((noise_value - hill_threshold) / maxf(0.01, 1.0 - hill_threshold), 0.0, 1.0)
	# Smooth slopes; ease toward flatter hilltops.
	t = t * t * (3.0 - 2.0 * t)
	var plateau_start: float = lerpf(0.85, 0.4, hilltop_flatness)
	if t > plateau_start:
		var top_t: float = (t - plateau_start) / (1.0 - plateau_start)
		t = lerpf(t, plateau_start + (1.0 - plateau_start) * (top_t * top_t * (3.0 - 2.0 * top_t)), hilltop_flatness)

	var distance: float = Vector2(world_x - starting_position.x, world_z - starting_position.z).length()
	var blend: float = clampf((distance - start_flat_radius) / maxf(0.01, start_blend_width), 0.0, 1.0)
	blend = blend * blend * (3.0 - 2.0 * blend)
	return t * hill_height * blend


func _create_terrain_mesh(parent: Node3D, coord: Vector2i) -> void:
	var cells_per_side: int = maxi(
		1,
		roundi(chunk_size / terrain_cell_size)
	)

	var cell_size: float = chunk_size / float(cells_per_side)

	var vertices: Array = []
	var normals: Array = []
	var uvs: Array = []
	var indices: Array = []

	for terrain_type in range(3):
		vertices.append(PackedVector3Array())
		normals.append(PackedVector3Array())
		uvs.append(PackedVector2Array())
		indices.append(PackedInt32Array())

	for x in range(cells_per_side):
		for z in range(cells_per_side):
			var x0: float = float(x) * cell_size
			var z0: float = float(z) * cell_size
			var x1: float = x0 + cell_size
			var z1: float = z0 + cell_size

			var world_x: float = float(coord.x) * chunk_size + x0
			var world_z: float = float(coord.y) * chunk_size + z0

			var terrain_type := _get_terrain_type(
				world_x + cell_size * 0.5,
				world_z + cell_size * 0.5
			)

			var v: PackedVector3Array = vertices[terrain_type]
			var n: PackedVector3Array = normals[terrain_type]
			var uv: PackedVector2Array = uvs[terrain_type]
			var idx: PackedInt32Array = indices[terrain_type]

			var start_index: int = v.size()

			var h00: float = _get_height(world_x, world_z)
			var h01: float = _get_height(world_x, world_z + cell_size)
			var h11: float = _get_height(world_x + cell_size, world_z + cell_size)
			var h10: float = _get_height(world_x + cell_size, world_z)
			v.append(Vector3(x0, h00, z0))
			v.append(Vector3(x0, h01, z1))
			v.append(Vector3(x1, h11, z1))
			v.append(Vector3(x1, h10, z0))

			# World-space gradient normals avoid lighting seams between chunks.
			var normal_step: float = cell_size
			for point in [Vector2(world_x, world_z), Vector2(world_x, world_z + cell_size), Vector2(world_x + cell_size, world_z + cell_size), Vector2(world_x + cell_size, world_z)]:
				var dx: float = (_get_height(point.x + normal_step, point.y) - _get_height(point.x - normal_step, point.y)) / (2.0 * normal_step)
				var dz: float = (_get_height(point.x, point.y + normal_step) - _get_height(point.x, point.y - normal_step)) / (2.0 * normal_step)
				n.append(Vector3(-dx, 1.0, -dz).normalized())

			var uv_x0: float = world_x * TEXTURE_REPEATS_PER_UNIT
			var uv_z0: float = world_z * TEXTURE_REPEATS_PER_UNIT
			var uv_x1: float = (world_x + cell_size) * TEXTURE_REPEATS_PER_UNIT
			var uv_z1: float = (world_z + cell_size) * TEXTURE_REPEATS_PER_UNIT

			uv.append(Vector2(uv_x0, uv_z0))
			uv.append(Vector2(uv_x0, uv_z1))
			uv.append(Vector2(uv_x1, uv_z1))
			uv.append(Vector2(uv_x1, uv_z0))

			idx.append_array(PackedInt32Array([
				start_index,
				start_index + 2,
				start_index + 1,
				start_index,
				start_index + 3,
				start_index + 2
			]))

	var mesh := ArrayMesh.new()

	for terrain_type in range(3):
		var v: PackedVector3Array = vertices[terrain_type]

		if v.is_empty():
			continue

		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)

		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = normals[terrain_type]
		arrays[Mesh.ARRAY_TEX_UV] = uvs[terrain_type]
		arrays[Mesh.ARRAY_INDEX] = indices[terrain_type]

		mesh.add_surface_from_arrays(
			Mesh.PRIMITIVE_TRIANGLES,
			arrays
		)

		var surface_index: int = mesh.get_surface_count() - 1
		mesh.surface_set_material(
			surface_index,
			terrain_materials[terrain_type]
		)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "TerrainMesh"
	mesh_instance.mesh = mesh
	parent.add_child(mesh_instance)

	# Use the same triangles for terrain collision, so hills are walkable.
	var floor_body := StaticBody3D.new()
	floor_body.name = "TerrainCollision"
	# Physics layer 3 (bitmask 4), matching enemy and spawner ground masks.
	floor_body.collision_layer = 4
	floor_body.collision_mask = 5
	parent.add_child(floor_body)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = mesh.create_trimesh_shape()
	floor_body.add_child(collision)


func _create_chunk_trees(parent: Node3D, coord: Vector2i) -> void:
	if oak_tree_scene == null or tree_density <= 0.0:
		return

	var trees := Node3D.new()
	trees.name = "Trees"
	parent.add_child(trees)

	# A fixed world-space grid ensures spacing even across chunk edges.
	var spacing: float = maxf(tree_spacing, 2.0)
	var min_grid_x: int = ceili(float(coord.x) * chunk_size / spacing)
	var max_grid_x: int = ceili(float(coord.x + 1) * chunk_size / spacing)
	var min_grid_z: int = ceili(float(coord.y) * chunk_size / spacing)
	var max_grid_z: int = ceili(float(coord.y + 1) * chunk_size / spacing)

	for gx in range(min_grid_x, max_grid_x):
		for gz in range(min_grid_z, max_grid_z):
			var rng := RandomNumberGenerator.new()
			rng.seed = _tree_cell_seed(gx, gz)

			# Leave room between neighboring grid cells.
			var jitter: float = spacing * 0.2
			var world_x: float = (float(gx) + 0.5) * spacing + rng.randf_range(-jitter, jitter)
			var world_z: float = (float(gz) + 0.5) * spacing + rng.randf_range(-jitter, jitter)

			# Keep ownership in the correct chunk if spacing doesn't divide chunk_size.
			if floori(world_x / chunk_size) != coord.x or floori(world_z / chunk_size) != coord.y:
				continue

			var offset := Vector2(world_x - starting_position.x, world_z - starting_position.z)
			if offset.length() < spawn_clear_radius:
				continue

			# Never place trees on or next to a house plot.
			if _near_house_plot(world_x, world_z):
				continue

			# Grass only, matching the actual terrain-cell sampling.
			if _get_visible_terrain_type(world_x, world_z) != 0:
				continue

			var forest_value: float = forest_noise.get_noise_2d(world_x, world_z)
			var forest_factor: float = clampf((forest_value + 0.2) / 0.6, 0.0, 1.0)
			var chance: float = tree_density * forest_factor

			if rng.randf() > chance:
				continue

			var tree := oak_tree_scene.instantiate() as Node3D
			if tree == null:
				continue

			trees.add_child(tree)
			tree.position = Vector3(
				world_x - float(coord.x) * chunk_size,
				_get_height(world_x, world_z),
				world_z - float(coord.y) * chunk_size
			)
			tree.rotation.y = rng.randf_range(0.0, TAU)


func _get_visible_terrain_type(world_x: float, world_z: float) -> int:
	var cells_per_side: int = maxi(1, roundi(chunk_size / terrain_cell_size))
	var cell_size: float = chunk_size / float(cells_per_side)
	var chunk_x: int = floori(world_x / chunk_size)
	var chunk_z: int = floori(world_z / chunk_size)
	var local_x: float = world_x - float(chunk_x) * chunk_size
	var local_z: float = world_z - float(chunk_z) * chunk_size
	var cell_x: int = clampi(floori(local_x / cell_size), 0, cells_per_side - 1)
	var cell_z: int = clampi(floori(local_z / cell_size), 0, cells_per_side - 1)
	return _get_terrain_type(
		float(chunk_x) * chunk_size + (float(cell_x) + 0.5) * cell_size,
		float(chunk_z) * chunk_size + (float(cell_z) + 0.5) * cell_size
	)


func _tree_cell_seed(gx: int, gz: int) -> int:
	# Stable integer hashing; independent of chunk creation order.
	var value: int = world_seed
	value = (value ^ (gx * 73856093)) & 0x7FFFFFFF
	value = (value ^ (gz * 19349663)) & 0x7FFFFFFF
	return value


func _house_cell_seed(gx: int, gz: int) -> int:
	var value: int = world_seed + 57431
	value = (value ^ (gx * 92837111)) & 0x7FFFFFFF
	value = (value ^ (gz * 689287499)) & 0x7FFFFFFF
	return value


func _get_house_data(gx: int, gz: int) -> Dictionary:
	var key := Vector2i(gx, gz)
	if house_cache.has(key):
		return house_cache[key]

	var result: Dictionary = {}
	if house_scene == null or house_chance <= 0.0:
		house_cache[key] = result
		return result

	var rng := RandomNumberGenerator.new()
	rng.seed = _house_cell_seed(gx, gz)
	var jitter: float = minf(8.0, house_spacing * 0.12)
	var x: float = (float(gx) + 0.5) * house_spacing + rng.randf_range(-jitter, jitter)
	var z: float = (float(gz) + 0.5) * house_spacing + rng.randf_range(-jitter, jitter)
	var center := Vector2(x, z)

	if rng.randf() <= house_chance:
		var spawn_center := Vector2(starting_position.x, starting_position.z)
		if center.distance_to(spawn_center) >= house_spawn_clear_radius:
			var elevation: float = _get_natural_height(x, z)
			if elevation >= house_min_hill_height:
				result = {"center": center, "height": elevation}

	house_cache[key] = result
	return result


func _near_house_plot(world_x: float, world_z: float) -> bool:
	if house_scene == null or house_chance <= 0.0:
		return false
	var gx: int = floori(world_x / house_spacing)
	var gz: int = floori(world_z / house_spacing)
	var point := Vector2(world_x, world_z)
	for x in range(gx - 1, gx + 2):
		for z in range(gz - 1, gz + 2):
			var data: Dictionary = _get_house_data(x, z)
			if not data.is_empty():
				var center: Vector2 = data["center"]
				if point.distance_to(center) < house_plot_radius + house_plot_blend + 1.5:
					return true
	return false


func _create_chunk_houses(parent: Node3D, coord: Vector2i) -> void:
	if house_scene == null or house_chance <= 0.0:
		return

	var houses := Node3D.new()
	houses.name = "Houses"
	parent.add_child(houses)

	var min_x: int = floori(float(coord.x) * chunk_size / house_spacing) - 1
	var max_x: int = floori(float(coord.x + 1) * chunk_size / house_spacing) + 1
	var min_z: int = floori(float(coord.y) * chunk_size / house_spacing) - 1
	var max_z: int = floori(float(coord.y + 1) * chunk_size / house_spacing) + 1

	for gx in range(min_x, max_x + 1):
		for gz in range(min_z, max_z + 1):
			var data: Dictionary = _get_house_data(gx, gz)
			if data.is_empty():
				continue
			var center: Vector2 = data["center"]
			# Only the chunk containing the center owns the house instance.
			if floori(center.x / chunk_size) != coord.x or floori(center.y / chunk_size) != coord.y:
				continue
			var house := house_scene.instantiate() as Node3D
			if house == null:
				push_warning("OverworldGenerator: House scene root must be Node3D.")
				return
			houses.add_child(house)
			house.position = Vector3(
				center.x - float(coord.x) * chunk_size,
				float(data["height"]),
				center.y - float(coord.y) * chunk_size
			)
