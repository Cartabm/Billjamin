extends RefCounted

# Builds a single visual rock surface outside rooms and corridors.
# No physics bodies, no collision shapes, no per-tile nodes.
# The open rooms/corridors remain uncovered.
static func build(
		connections: Dictionary,
		room_size: float,
		corridor_length: float,
		doorway_width: float,
		rock_material: Material,
		wall_height: float = 5.0
) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.name = "GeneratedRockFill"
	if connections.is_empty():
		return result

	var spacing: float = room_size + corridor_length
	var half_room: float = room_size * 0.5
	var rectangles: Array[Vector4] = []
	var min_x: float = INF
	var max_x: float = -INF
	var min_z: float = INF
	var max_z: float = -INF

	# Exclude each room interior AND its wall thickness from the rock surface.
	for cell in connections.keys():
		var center_x: float = float(cell.x) * spacing
		var center_z: float = float(cell.y) * spacing
		var extent: float = half_room + 0.5
		rectangles.append(Vector4(
			center_x - extent, center_z - extent,
			center_x + extent, center_z + extent
		))
		min_x = minf(min_x, center_x - extent)
		max_x = maxf(max_x, center_x + extent)
		min_z = minf(min_z, center_z - extent)
		max_z = maxf(max_z, center_z + extent)

	# Exclude corridor interiors and their outer walls.
	# Each undirected connection is visited once.
	var corridor_half_width: float = doorway_width * 0.5 + 1.0
	for cell in connections.keys():
		for direction in connections[cell]:
			var neighbor: Vector2i = cell + direction
			if not connections.has(neighbor):
				continue
			if cell.x > neighbor.x or (cell.x == neighbor.x and cell.y > neighbor.y):
				continue

			var a := Vector2(float(cell.x) * spacing, float(cell.y) * spacing)
			var b := Vector2(float(neighbor.x) * spacing, float(neighbor.y) * spacing)
			if direction.x != 0:
				rectangles.append(Vector4(
					minf(a.x, b.x) + half_room,
					a.y - corridor_half_width,
					maxf(a.x, b.x) - half_room,
					a.y + corridor_half_width
				))
			else:
				rectangles.append(Vector4(
					a.x - corridor_half_width,
					minf(a.y, b.y) + half_room,
					a.x + corridor_half_width,
					maxf(a.y, b.y) - half_room
				))

	# An extra rock border keeps the visible edge away from the camera.
	var border: float = room_size * 1.5
	min_x -= border
	max_x += border
	min_z -= border
	max_z += border

	# Only split along actual room/corridor edges. This produces a small
	# number of long rectangles instead of thousands of little rock tiles.
	var z_edges: Array[float] = [min_z, max_z]
	for rect in rectangles:
		z_edges.append(rect.y)
		z_edges.append(rect.w)
	z_edges.sort()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top_y: float = wall_height - 0.02
	var quad_count: int = 0

	for i in range(z_edges.size() - 1):
		var z0: float = z_edges[i]
		var z1: float = z_edges[i + 1]
		if z1 - z0 < 0.001:
			continue
		var middle_z: float = (z0 + z1) * 0.5

		var occupied: Array[Vector2] = []
		for rect in rectangles:
			if middle_z > rect.y and middle_z < rect.w:
				occupied.append(Vector2(rect.x, rect.z))
		occupied.sort_custom(func(a: Vector2, b: Vector2) -> bool:
			return a.x < b.x
		)

		var cursor: float = min_x
		for interval in occupied:
			var left: float = maxf(min_x, interval.x)
			var right: float = minf(max_x, interval.y)
			if left > cursor + 0.001:
				_add_top_quad(st, cursor, z0, left, z1, top_y)
				quad_count += 1
			cursor = maxf(cursor, right)
		if cursor < max_x - 0.001:
			_add_top_quad(st, cursor, z0, max_x, z1, top_y)
			quad_count += 1

	if quad_count > 0:
		result.mesh = st.commit()
		result.material_override = rock_material
		result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return result


static func _add_top_quad(
		st: SurfaceTool, x0: float, z0: float,
		x1: float, z1: float, y: float
) -> void:
	# Winding faces upward. UVs are world-scaled, so the texture repeats.
	_vertex(st, x0, y, z0)
	_vertex(st, x0, y, z1)
	_vertex(st, x1, y, z0)
	_vertex(st, x1, y, z0)
	_vertex(st, x0, y, z1)
	_vertex(st, x1, y, z1)


static func _vertex(st: SurfaceTool, x: float, y: float, z: float) -> void:
	st.set_normal(Vector3.UP)
	st.set_uv(Vector2(x, z) * 0.2)
	st.add_vertex(Vector3(x, y, z))
