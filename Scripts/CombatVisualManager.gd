extends Node3D
## Shared, pooled, cosmetic-only combat visuals. Add as an Autoload named CombatVisualManager.
## No damage or collision logic lives here. Enemy warnings are always red.

const WARNING_COLOR := Color(1.0, 0.13, 0.12, 0.90)
const PLAYER_COLOR := Color(1.0, 0.68, 0.19, 0.85)
const RANGE_COLOR := Color(0.18, 0.77, 1.0, 0.45)
const MAX_COSMETIC_EFFECTS: int = 80
const MAX_WARNING_EFFECTS: int = 256

var _meshes: Dictionary = {}
var _materials: Dictionary = {}
var _available: Array[MeshInstance3D] = []
var _active: Array[Dictionary] = []
var _cosmetic_count: int = 0
var _warning_count: int = 0

func _ready() -> void:
	set_process(false)
	# Shared meshes and materials are built only once, never per frame.
	_meshes["ring"] = _build_ring(64, 0.965)
	_meshes["line"] = _build_line()
	_materials["warning"] = _make_material(WARNING_COLOR)
	_materials["player"] = _make_material(PLAYER_COLOR)
	_materials["range"] = _make_material(RANGE_COLOR)

func create_range_indicator(parent: Node3D) -> MeshInstance3D:
	var indicator := MeshInstance3D.new()
	indicator.name = "BasicAttackRangeVisual"
	indicator.mesh = _meshes["ring"]
	indicator.material_override = _materials["range"]
	indicator.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	indicator.position.y = 0.10
	parent.add_child(indicator)
	return indicator

func create_target_marker(parent: Node3D) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	marker.name = "InRangeTargetVisual"
	marker.mesh = _meshes["ring"]
	marker.material_override = _materials["range"]
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.position.y = 0.12
	marker.scale = Vector3(0.65, 1.0, 0.65)
	marker.visible = false
	parent.add_child(marker)
	return marker

func player_slash(world_position: Vector3, radius: float, yaw: float, angle_deg: float = 90.0) -> void:
	_spawn("slash", world_position, radius, yaw, 0.24, false, angle_deg)

func player_burst(world_position: Vector3, radius: float) -> void:
	_spawn("burst", world_position, radius, 0.0, 0.30, false)

func warning_circle(world_position: Vector3, radius: float, duration: float) -> void:
	_spawn("ring", world_position, radius, 0.0, duration, true)

func warning_cone(world_position: Vector3, radius: float, yaw: float, angle_deg: float, duration: float) -> void:
	_spawn("cone", world_position, radius, yaw, duration, true, angle_deg)

func warning_line(world_position: Vector3, direction: Vector3, length: float, width: float, duration: float) -> void:
	if direction.length_squared() < 0.0001:
		return
	var yaw: float = atan2(-direction.x, -direction.z)
	_spawn("line", world_position, length, yaw, duration, true, 90.0, width)

func _spawn(kind: String, world_position: Vector3, radius: float, yaw: float, duration: float, warning: bool, angle_deg: float = 90.0, width: float = 1.0) -> void:
	if radius <= 0.0:
		return
	if warning:
		if _warning_count >= MAX_WARNING_EFFECTS:
			# Never replace an existing enemy warning with a cosmetic effect.
			return
	else:
		if _cosmetic_count >= MAX_COSMETIC_EFFECTS:
			return
	var visual: MeshInstance3D
	if _available.is_empty():
		visual = MeshInstance3D.new()
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(visual)
	else:
		visual = _available.pop_back()
	var shape: String = "ring"
	if kind == "line":
		shape = "line"
	elif kind == "cone" or kind == "slash":
		shape = "cone_%d" % roundi(angle_deg)
		if not _meshes.has(shape):
			_meshes[shape] = _build_cone_outline(angle_deg, 48)
	visual.mesh = _meshes[shape]
	visual.material_override = _materials["warning" if warning else "player"]
	visual.global_position = world_position + Vector3(0.0, 0.11, 0.0)
	visual.rotation.y = yaw
	visual.scale = Vector3(width, 1.0, radius) if kind == "line" else Vector3(radius, 1.0, radius)
	visual.transparency = 0.0
	visual.visible = true
	_active.append({"node": visual, "kind": kind, "age": 0.0, "duration": maxf(0.05, duration), "radius": radius, "width": width, "yaw": yaw, "warning": warning})
	if warning:
		_warning_count += 1
	else:
		_cosmetic_count += 1
	set_process(true)

func _process(delta: float) -> void:
	for i in range(_active.size() - 1, -1, -1):
		var effect: Dictionary = _active[i]
		var visual: MeshInstance3D = effect["node"]
		var age: float = float(effect["age"]) + delta
		var duration: float = effect["duration"]
		if age >= duration:
			visual.visible = false
			visual.transparency = 0.0
			_available.append(visual)
			if effect["warning"]:
				_warning_count -= 1
			else:
				_cosmetic_count -= 1
			_active.remove_at(i)
			continue
		effect["age"] = age
		var t: float = age / duration
		var kind: String = effect["kind"]
		if effect["warning"]:
			# Strong readable warnings stay visible until the attack begins.
			visual.transparency = 0.12 + 0.14 * sin(t * TAU * 2.0)
		elif kind == "slash":
			visual.rotation.y = float(effect["yaw"]) + t * PI * 0.7
			visual.transparency = t * 0.90
		elif kind == "burst":
			var scale_value: float = float(effect["radius"]) * (0.65 + 0.35 * t)
			visual.scale = Vector3(scale_value, 1.0, scale_value)
			visual.transparency = t
		else:
			visual.transparency = t
		_active[i] = effect
	if _active.is_empty():
		set_process(false)

func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.no_depth_test = true
	return material

func _build_ring(segments: int, inner_radius: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	for i in range(segments):
		var a0: float = TAU * float(i) / float(segments)
		var a1: float = TAU * float(i + 1) / float(segments)
		_append_quad(vertices, Vector3(sin(a0) * inner_radius, 0, cos(a0) * inner_radius), Vector3(sin(a0), 0, cos(a0)), Vector3(sin(a1), 0, cos(a1)), Vector3(sin(a1) * inner_radius, 0, cos(a1) * inner_radius))
	return _mesh_from_vertices(vertices)

func _build_cone_outline(angle_deg: float, segments: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var half_angle: float = deg_to_rad(clampf(angle_deg, 1.0, 360.0) * 0.5)
	for i in range(segments):
		var a0: float = lerpf(-half_angle, half_angle, float(i) / float(segments))
		var a1: float = lerpf(-half_angle, half_angle, float(i + 1) / float(segments))
		_append_quad(vertices, _arc_point(a0, 0.965), _arc_point(a0, 1.0), _arc_point(a1, 1.0), _arc_point(a1, 0.965))
	for a in [-half_angle, half_angle]:
		var side: Vector3 = _arc_point(a, 1.0)
		var perpendicular := Vector3(-side.z, 0, side.x) * 0.02
		_append_quad(vertices, -perpendicular, perpendicular, side + perpendicular, side - perpendicular)
	return _mesh_from_vertices(vertices)

func _arc_point(angle: float, distance: float) -> Vector3:
	return Vector3(sin(angle) * distance, 0.0, -cos(angle) * distance)

func _build_line() -> ArrayMesh:
	var vertices := PackedVector3Array()
	_append_quad(vertices, Vector3(-0.5, 0, 0), Vector3(-0.46, 0, 0), Vector3(-0.46, 0, -1), Vector3(-0.5, 0, -1))
	_append_quad(vertices, Vector3(0.46, 0, 0), Vector3(0.5, 0, 0), Vector3(0.5, 0, -1), Vector3(0.46, 0, -1))
	_append_quad(vertices, Vector3(-0.5, 0, -1), Vector3(0.5, 0, -1), Vector3(0.5, 0, -0.97), Vector3(-0.5, 0, -0.97))
	return _mesh_from_vertices(vertices)

func _append_quad(vertices: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	vertices.append_array(PackedVector3Array([a, b, c, a, c, d]))

func _mesh_from_vertices(vertices: PackedVector3Array) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
