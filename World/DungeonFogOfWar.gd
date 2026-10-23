extends Node3D

@export var fog_height: float = 4.8
@export var unexplored_opacity: float = 0.98
@export var explored_opacity: float = 0.45

var fog_tiles: Dictionary = {}
var generator: Node3D


func setup(dungeon_generator: Node3D) -> void:
	generator = dungeon_generator
	clear_fog()

	var room_size: float = generator.get_room_size()

	for cell in generator.connections.keys():
		var fog_tile := MeshInstance3D.new()
		fog_tile.name = "Fog_%d_%d" % [cell.x, cell.y]

		var mesh := PlaneMesh.new()
		mesh.size = Vector2(room_size, room_size)
		fog_tile.mesh = mesh

		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.12, 0.14, 0.17, unexplored_opacity)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		fog_tile.material_override = material

		add_child(fog_tile)
		fog_tile.global_position = Vector3(
			cell.x * generator.get_grid_spacing(),
			fog_height,
			cell.y * generator.get_grid_spacing()
		)

		fog_tiles[cell] = fog_tile

	update_visibility()


func update_visibility() -> void:
	if generator == null:
		return

	for cell in fog_tiles.keys():
		var tile: MeshInstance3D = fog_tiles[cell]

		if cell == generator.current_exploration_room:
			tile.visible = false
		elif generator.explored_rooms.has(cell):
			tile.visible = true
			_set_opacity(tile, explored_opacity)
		else:
			tile.visible = true
			_set_opacity(tile, unexplored_opacity)


func _set_opacity(tile: MeshInstance3D, opacity: float) -> void:
	var material := tile.material_override as StandardMaterial3D
	material.albedo_color.a = opacity


func clear_fog() -> void:
	for child in get_children():
		child.queue_free()

	fog_tiles.clear()
