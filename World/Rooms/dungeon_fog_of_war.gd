extends Node3D
# Fog of war: dark, gently moving covers hide unvisited rooms.
# One visual plane per room/corridor. No physics or per-frame fog updates.

var visited: Dictionary = {}
var room_covers: Dictionary = {}
var corridor_covers: Dictionary = {}
var fog_material: ShaderMaterial

func _ready() -> void:
	name = "DungeonFogOfWar"


func reset_visits() -> void:
	visited.clear()


func rebuild(connections: Dictionary, room_size: float, corridor_length: float,
		doorway_width: float, wall_height: float) -> void:
	# Remove previous covers, but keep the visited state for boss-room additions.
	for child in get_children():
		remove_child(child)
		child.queue_free()
	room_covers.clear()
	corridor_covers.clear()
	if fog_material == null:
		fog_material = _make_fog_material()

	var spacing: float = room_size + corridor_length
	var roof_y: float = wall_height + 0.0

	for cell in connections.keys():
		var center := Vector3(float(cell.x) * spacing, roof_y,
				float(cell.y) * spacing)
		var cover := _add_cover("FogRoom_%d_%d" % [cell.x, cell.y],
				center, Vector2(room_size + 1.2, room_size + 1.2))
		room_covers[cell] = cover

	for cell in connections.keys():
		for direction in connections[cell]:
			var neighbor: Vector2i = cell + direction
			if not connections.has(neighbor):
				continue
			if _cell_after(cell, neighbor):
				continue
			var center := Vector3(
					float(cell.x + neighbor.x) * spacing * 0.5,
					roof_y,
					float(cell.y + neighbor.y) * spacing * 0.5)
			var size: Vector2
			if cell.x != neighbor.x:
				size = Vector2(corridor_length + 0.6, doorway_width + 2.0)
			else:
				size = Vector2(doorway_width + 2.0, corridor_length + 0.6)
			var cover := _add_cover("FogCorridor_%d_%d_to_%d_%d" %
					[cell.x, cell.y, neighbor.x, neighbor.y], center, size)
			corridor_covers[_edge_key(cell, neighbor)] = cover

	# Restore exploration when rebuilding for the newly generated boss room.
	for cell in visited.keys():
		_show_visited(cell, connections)


func reveal_room(cell: Vector2i, connections: Dictionary) -> void:
	if visited.has(cell):
		return
	if not connections.has(cell):
		return
	visited[cell] = true
	_show_visited(cell, connections)


func _show_visited(cell: Vector2i, connections: Dictionary) -> void:
	if room_covers.has(cell):
		room_covers[cell].visible = false
	if not connections.has(cell):
		return
	# Show corridors connected to a visited room, while keeping their
	# unexplored destination rooms hidden.
	for direction in connections[cell]:
		var neighbor: Vector2i = cell + direction
		var key: String = _edge_key(cell, neighbor)
		if corridor_covers.has(key):
			corridor_covers[key].visible = false


func _add_cover(cover_name: String, center: Vector3,
		footprint: Vector2) -> MeshInstance3D:
	var cover := MeshInstance3D.new()
	cover.name = cover_name
	var plane := PlaneMesh.new()
	plane.size = footprint
	cover.mesh = plane
	cover.material_override = fog_material
	cover.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cover)
	cover.position = center
	return cover


func _cell_after(a: Vector2i, b: Vector2i) -> bool:
	return a.x > b.x or (a.x == b.x and a.y > b.y)


func _edge_key(a: Vector2i, b: Vector2i) -> String:
	if _cell_after(a, b):
		var tmp: Vector2i = a
		a = b
		b = tmp
	return "%d,%d:%d,%d" % [a.x, a.y, b.x, b.y]


func get_fog_material() -> ShaderMaterial:
	if fog_material == null:
		fog_material = _make_fog_material()
	return fog_material


func _make_fog_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
varying vec3 world_point;
void vertex() {
    world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    float drift = sin(world_point.x * 0.31 + TIME * 0.24)
        * sin(world_point.z * 0.27 - TIME * 0.19);
    float wisps = sin(world_point.x * 0.73 + world_point.z * 0.43
        + TIME * 0.13);
    float shade = 0.86 + 0.10 * drift + 0.04 * wisps;
    ALBEDO = vec3(0.065, 0.072, 0.082) * shade;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material
