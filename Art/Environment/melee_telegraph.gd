
extends MeshInstance3D

@export_group("Attack Geometry")
@export var attack_range: float = 5.0
@export var attack_angle: float = 90.0
@export var segments: int = 48
@export var border_width: float = 0.10

@export_group("Appearance")
@export var outline_color: Color = Color(1.0, 0.16, 0.12, 1.0)
@export var fill_color: Color = Color(1.0, 0.12, 0.08, 0.65)

@export_group("Terrain Following")
@export_flags_3d_physics var terrain_collision_mask: int = 4
@export var terrain_offset: float = 0.08
@export var terrain_sample_spacing: float = 0.5
@export var raycast_height: float = 15.0
@export var raycast_depth: float = 35.0

@export_group("Performance")
@export var update_interval: float = 0.05

var charge: float = 0.0
var telegraph_material: StandardMaterial3D
var range_multiplier: float = 1.0

func set_range_multiplier(value: float) -> void:
	var new_multiplier: float = maxf(0.01, value)

	if is_equal_approx(range_multiplier, new_multiplier):
		return

	range_multiplier = new_multiplier
	_mesh_dirty = true

var _last_transform: Transform3D
var _update_timer: float = 0.0
var _mesh_dirty: bool = true


func _ready() -> void:
	_create_material()
	_last_transform = global_transform
	_create_mesh()
	_mesh_dirty = false


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

	# Five visual states: 0, 25, 50, 75, 100%.
	var stepped_charge := floorf(
		new_charge * 4.0 + 0.0001
	) / 4.0

	if is_equal_approx(stepped_charge, charge):
		return

	charge = stepped_charge

	# Update immediately when reaching each stage.
	_last_transform = global_transform
	_create_mesh()
	_mesh_dirty = false
	_update_timer = 0.0


func _create_material() -> void:
	telegraph_material = StandardMaterial3D.new()

	# Use vertex colors instead of a texture.
	telegraph_material.vertex_color_use_as_albedo = true
	telegraph_material.albedo_color = Color.WHITE

	telegraph_material.transparency = (
		BaseMaterial3D.TRANSPARENCY_ALPHA
	)

	telegraph_material.shading_mode = (
		BaseMaterial3D.SHADING_MODE_UNSHADED
	)

	telegraph_material.cull_mode = (
		BaseMaterial3D.CULL_DISABLED
	)

	# Render without depth testing so scenery cannot hide it.
	telegraph_material.no_depth_test = true

	telegraph_material.depth_draw_mode = (
		BaseMaterial3D.DEPTH_DRAW_DISABLED
	)

	telegraph_material.render_priority = 10

	material_override = telegraph_material

	# Give terrain-following geometry generous visibility bounds.
	custom_aabb = AABB(
		Vector3(-100.0, -100.0, -100.0),
		Vector3(200.0, 200.0, 200.0)
	)


func _create_mesh() -> void:
	if not is_inside_tree():
		return

	var vertices := PackedVector3Array()
	var colors := PackedColorArray()

	var radius := maxf(0.01, attack_range * range_multiplier)
	var half_angle := deg_to_rad(attack_angle * 0.5)
	var full_angle := half_angle * 2.0
	var arc_segments := maxi(3, segments)

	var radial_steps := maxi(
		1,
		ceili(radius / maxf(0.1, terrain_sample_spacing))
	)

	# ============================================
	# 1. CHARGING FILL
	# ============================================

	# The fill grows from the Rogue outward.
	# The outer outline does not change size.

	if charge > 0.0:
		var fill_radius := radius * charge

		var fill_steps := maxi(
			1,
			ceili(
				fill_radius /
				maxf(0.1, terrain_sample_spacing)
			)
		)

		for i in range(arc_segments):
			var a0 := (
				-half_angle +
				full_angle * float(i) / arc_segments
			)

			var a1 := (
				-half_angle +
				full_angle * float(i + 1) / arc_segments
			)

			for j in range(fill_steps):
				var r0 := (
					fill_radius * float(j) / fill_steps
				)

				var r1 := (
					fill_radius * float(j + 1) / fill_steps
				)

				_add_quad(
					vertices,
					colors,
					_point(a0, r0, 0.01),
					_point(a0, r1, 0.01),
					_point(a1, r1, 0.01),
					_point(a1, r0, 0.01),
					fill_color
				)

	# ============================================
	# 2. OUTER CURVED BORDER
	# ============================================

	var inner_radius := maxf(
		0.0,
		radius - border_width
	)

	for i in range(arc_segments):
		var a0 := (
			-half_angle +
			full_angle * float(i) / arc_segments
		)

		var a1 := (
			-half_angle +
			full_angle * float(i + 1) / arc_segments
		)

		_add_quad(
			vertices,
			colors,
			_point(a0, inner_radius, 0.02),
			_point(a0, radius, 0.02),
			_point(a1, radius, 0.02),
			_point(a1, inner_radius, 0.02),
			outline_color
		)

	# ============================================
	# 3. STRAIGHT SIDE BORDERS
	# ============================================

	for side in range(2):
		var angle := -half_angle if side == 0 else half_angle

		var inside_direction := Vector3(
			cos(angle),
			0.0,
			sin(angle)
		)

		if side == 1:
			inside_direction = -inside_direction

		var offset := inside_direction * border_width

		for j in range(radial_steps):
			var r0 := radius * float(j) / radial_steps
			var r1 := radius * float(j + 1) / radial_steps

			var p0 := _point(angle, r0, 0.02)
			var p1 := _point(angle, r1, 0.02)

			_add_quad(
				vertices,
				colors,
				p0,
				p1,
				p1 + offset,
				p0 + offset,
				outline_color
			)

	# ============================================
	# 4. FOLLOW TERRAIN HEIGHT
	# ============================================

	var height_cache: Dictionary = {}
	var space := get_world_3d().direct_space_state
	var inverse_transform := global_transform.affine_inverse()

	for index in range(vertices.size()):
		var local_vertex := vertices[index]
		var world_vertex := global_transform * local_vertex

		var key := Vector2i(
			roundi(world_vertex.x * 4.0),
			roundi(world_vertex.z * 4.0)
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
				from,
				to,
				terrain_collision_mask
			)

			query.collide_with_areas = false

			var hit := space.intersect_ray(query)

			if not hit.is_empty():
				terrain_y = (hit["position"] as Vector3).y
			else:
				terrain_y = global_position.y

			height_cache[key] = terrain_y

		world_vertex.y = (
			terrain_y +
			terrain_offset +
			local_vertex.y
		)

		vertices[index] = inverse_transform * world_vertex

	# ============================================
	# 5. BUILD MESH
	# ============================================

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors

	var generated_mesh := ArrayMesh.new()

	generated_mesh.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES,
		arrays
	)

	mesh = generated_mesh


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
	_add_triangle(
		vertices, colors,
		a, b, c, color
	)

	_add_triangle(
		vertices, colors,
		a, c, d, color
	)
