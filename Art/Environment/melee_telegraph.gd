
extends MeshInstance3D

@export_group("Attack")
@export var attack_range: float = 5.0
@export var attack_angle: float = 90.0
@export var segments: int = 16
@export var border_width: float = 0.06

@export_group("Terrain Following")
@export_flags_3d_physics var terrain_collision_mask: int = 4
@export var terrain_offset: float = 0.035
@export var terrain_sample_spacing: float = 1.0
@export var raycast_height: float = 15.0
@export var raycast_depth: float = 35.0

@export_group("Performance")
@export var update_interval: float = 0.10

var charge: float = 0.0
var telegraph_material: StandardMaterial3D
var _last_transform: Transform3D
var _update_timer: float = 0.0
var _mesh_dirty: bool = true


func _ready() -> void:
	_create_material()
	_last_transform = global_transform
	_create_mesh()


func _process(delta: float) -> void:
	if not visible:
		return

	_update_timer += delta

	if not global_transform.is_equal_approx(_last_transform):
		_mesh_dirty = true

	if _mesh_dirty and _update_timer >= update_interval:
		_update_timer = 0.0
		_last_transform = global_transform
		_create_mesh()
		_mesh_dirty = false



func set_charge(value: float) -> void:
	var new_charge := clampf(value, 0.0, 1.0)

	# Only display 0%, 25%, 50%, 75%, or 100%.
	var stepped_charge := floorf(new_charge * 4.0 + 0.0001) / 4.0

	if is_equal_approx(stepped_charge, charge):
		return

	charge = stepped_charge
	_mesh_dirty = true

	# Update immediately at each 25% milestone.
	_last_transform = global_transform
	_create_mesh()
	_mesh_dirty = false
	_update_timer = 0.0



func _create_material() -> void:
	telegraph_material = StandardMaterial3D.new()
	telegraph_material.vertex_color_use_as_albedo = true
	telegraph_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	telegraph_material.albedo_texture = preload(
		"res://Assets/Textures/Combat/RogueTelegraph_PixelPattern.png"
	)
	telegraph_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	telegraph_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	telegraph_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	telegraph_material.no_depth_test = false
	telegraph_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material_override = telegraph_material


func _create_mesh() -> void:
	if not is_inside_tree():
		return

	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()

	var half_angle := deg_to_rad(attack_angle * 0.5)
	var full_angle := deg_to_rad(attack_angle)

	var radial_steps := maxi(
		1,
		ceili(attack_range / maxf(0.5, terrain_sample_spacing))
	)

	# Background attack cone.
	for i in range(segments):
		var a0 := -half_angle + full_angle * float(i) / segments
		var a1 := -half_angle + full_angle * float(i + 1) / segments

		_add_cone_strip(
			vertices, colors,
			a0, a1,
			attack_range,
			radial_steps,
			Color(1.0, 0.12, 0.08, 0.18)
		)

	# Animated charge cone.
	if charge > 0.0:
		var fill_range := attack_range * charge
		var fill_steps := maxi(
			1,
			ceili(fill_range / maxf(0.5, terrain_sample_spacing))
		)

		for i in range(segments):
			var a0 := -half_angle + full_angle * float(i) / segments
			var a1 := -half_angle + full_angle * float(i + 1) / segments

			_add_cone_strip(
				vertices, colors,
				a0, a1,
				fill_range,
				fill_steps,
				Color(1.0, 0.18, 0.10, 0.65),
				0.003
			)

	# Outer border.
	for i in range(segments):
		var a0 := -half_angle + full_angle * float(i) / segments
		var a1 := -half_angle + full_angle * float(i + 1) / segments

		_add_quad(
			vertices, colors,
			_point(a0, attack_range),
			_point(a1, attack_range),
			_point(a1, maxf(0.0, attack_range - border_width)),
			_point(a0, maxf(0.0, attack_range - border_width)),
			Color(1.0, 0.55, 0.3, 0.95)
		)

	# Side borders.
	for angle in [-half_angle, half_angle]:
		for j in range(radial_steps):
			var r0 := attack_range * float(j) / radial_steps
			var r1 := attack_range * float(j + 1) / radial_steps

			_add_quad(
				vertices, colors,
				_point(angle, r0),
				_point(angle, r1),
				_point(angle, maxf(0.0, r1 - border_width)),
				_point(angle, maxf(0.0, r0 - border_width)),
				Color(1.0, 0.55, 0.3, 0.95)
			)

	# Terrain height sampling, cached per mesh update.
	var height_cache: Dictionary = {}
	var space := get_world_3d().direct_space_state
	var inverse_transform := global_transform.affine_inverse()

	for index in range(vertices.size()):
		var local_vertex := vertices[index]
		var world_vertex := global_transform * local_vertex

		# Quantize sampling positions to a coarser grid.
		var key := Vector2i(
			roundi(world_vertex.x * 2.0),
			roundi(world_vertex.z * 2.0)
		)

		var terrain_y: float

		if height_cache.has(key):
			terrain_y = height_cache[key]
		else:
			var from := Vector3(
				world_vertex.x,
				global_position.y + raycast_height,
				world_vertex.z
			)

			var to := Vector3(
				world_vertex.x,
				global_position.y - raycast_depth,
				world_vertex.z
			)

			var query := PhysicsRayQueryParameters3D.create(
				from, to, terrain_collision_mask
			)
			query.collide_with_areas = false

			var hit := space.intersect_ray(query)

			terrain_y = (
				(hit["position"] as Vector3).y
				if not hit.is_empty()
				else world_vertex.y
			)

			height_cache[key] = terrain_y

		world_vertex.y = terrain_y + terrain_offset + local_vertex.y
		vertices[index] = inverse_transform * world_vertex

	# Texture coordinates.
	var texture_width := maxf(0.01, attack_range * 2.0)
	var texture_depth := maxf(0.01, attack_range)

	for vertex in vertices:
		uvs.append(
			Vector2(
				vertex.x / texture_width + 0.5,
				1.0 + vertex.z / texture_depth
			)
		)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs

	var generated_mesh := ArrayMesh.new()
	generated_mesh.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES, arrays
	)

	mesh = generated_mesh


func _add_cone_strip(
	vertices: PackedVector3Array,
	colors: PackedColorArray,
	a0: float,
	a1: float,
	radius: float,
	steps: int,
	color: Color,
	extra_height: float = 0.0
) -> void:

	for j in range(steps):
		var r0 := radius * float(j) / steps
		var r1 := radius * float(j + 1) / steps

		var p00 := _point(a0, r0, extra_height)
		var p01 := _point(a1, r0, extra_height)
		var p10 := _point(a0, r1, extra_height)
		var p11 := _point(a1, r1, extra_height)

		_add_triangle(vertices, colors, p00, p10, p11, color)
		_add_triangle(vertices, colors, p00, p11, p01, color)


func _point(
	angle: float,
	radius: float,
	height: float = 0.0
) -> Vector3:
	return Vector3(
		sin(angle) * radius,
		height,
		-cos(angle) * radius
	)


func _add_triangle(
	vertices: PackedVector3Array,
	colors: PackedColorArray,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	color: Color
) -> void:

	vertices.append(a)
	vertices.append(b)
	vertices.append(c)

	colors.append(color)
	colors.append(color)
	colors.append(color)


func _add_quad(
	vertices: PackedVector3Array,
	colors: PackedColorArray,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	color: Color
) -> void:

	_add_triangle(vertices, colors, a, b, c, color)
	_add_triangle(vertices, colors, a, c, d, color)
