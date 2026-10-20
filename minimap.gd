
extends Control

const SETTINGS_PATH := "user://settings.cfg"
const TEMP_DISABLE_MINIMAP := true

@export var map_radius: float = 20
@export var enemy_detection_radius: float = 30.0
@export var exploration_cell_size: float = 0.5
@export var refresh_interval: float = 0.15

const FRAME_COLOR := Color("#11181d")
const UNEXPLORED_COLOR := Color("#252d32")
const FLOOR_COLOR := Color("#424b4e")
const CROSSHAIR_COLOR := Color("#c4cdd0")
const PLAYER_COLOR := Color("#58c8ff")
const ENEMY_COLOR := Color("#ff3038")

var player: CharacterBody3D
var explored_cells: Dictionary = {}
var rotate_minimap: bool = false
var refresh_timer: float = 0.0


func _ready() -> void:
	add_to_group("minimap")

	if TEMP_DISABLE_MINIMAP:
		visible = false
		set_process(false)
		set_physics_process(false)
		return

	custom_minimum_size = Vector2(240.0, 240.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	player = get_tree().current_scene.get_node_or_null(
		"Player"
	) as CharacterBody3D

	_load_rotation_setting()
	_reveal_nearby_floor()
	queue_redraw()


func _process(delta: float) -> void:
	refresh_timer -= delta

	if refresh_timer > 0.0:
		return

	refresh_timer = refresh_interval

	if player == null or not is_instance_valid(player):
		player = get_tree().current_scene.get_node_or_null(
			"Player"
		) as CharacterBody3D

	if player != null:
		_reveal_nearby_floor()

	queue_redraw()


func _load_rotation_setting() -> void:
	var config := ConfigFile.new()
	var error := config.load(SETTINGS_PATH)

	if error == OK:
		rotate_minimap = config.get_value(
			"minimap",
			"rotate",
			false
		)


func set_rotation_enabled(enabled: bool) -> void:
	rotate_minimap = enabled
	queue_redraw()


func _reveal_nearby_floor() -> void:
	if player == null:
		return

	var player_cell := Vector2i(
		floori(player.global_position.x / exploration_cell_size),
		floori(player.global_position.z / exploration_cell_size)
	)

	var cell_radius := ceili(map_radius / exploration_cell_size)

	for x in range(
		player_cell.x - cell_radius,
		player_cell.x + cell_radius + 1
	):
		for z in range(
			player_cell.y - cell_radius,
			player_cell.y + cell_radius + 1
		):
			var cell := Vector2i(x, z)

			var cell_world_position := Vector2(
				(float(x) + 0.5) * exploration_cell_size,
				(float(z) + 0.5) * exploration_cell_size
			)

			var player_world_position := Vector2(
				player.global_position.x,
				player.global_position.z
			)

			if cell_world_position.distance_to(
				player_world_position
			) <= map_radius:
				explored_cells[cell] = true


func _world_to_map(world_position: Vector3) -> Vector2:
	var delta := world_position - player.global_position
	var horizontal := Vector2(delta.x, delta.z)

	if rotate_minimap:
		var local_x := delta.dot(player.global_basis.x)
		var local_z := delta.dot(player.global_basis.z)
		horizontal = Vector2(local_x, local_z)

	var map_size := minf(size.x, size.y) - 14.0
	var scale_factor := map_size / (map_radius * 2.0)

	return size * 0.5 + horizontal * scale_factor


func _draw() -> void:
	var map_size := minf(size.x, size.y)
	var outer_rect := Rect2(Vector2.ZERO, Vector2(map_size, map_size))
	var inset := 6.0
	var inner_rect := Rect2(
		Vector2(inset, inset),
		Vector2(map_size - inset * 2.0, map_size - inset * 2.0)
	)

	draw_rect(outer_rect, FRAME_COLOR)
	draw_rect(inner_rect, UNEXPLORED_COLOR)

	if player == null or not is_instance_valid(player):
		return

	var map_scale := (map_size - 14.0) / (map_radius * 2.0)
	var center := size * 0.5

	# Draw explored floor without grid lines.
	for cell_variant in explored_cells.keys():
		var cell: Vector2i = cell_variant

		var cell_world := Vector3(
			(float(cell.x) + 0.5) * exploration_cell_size,
			player.global_position.y,
			(float(cell.y) + 0.5) * exploration_cell_size
		)

		var cell_center := _world_to_map(cell_world)
		
		if not inner_rect.has_point(cell_center):
			continue
		

		var cell_pixel_size := exploration_cell_size * map_scale
		var cell_rect := Rect2(
			cell_center - Vector2.ONE * cell_pixel_size * 0.5,
			Vector2.ONE * (cell_pixel_size + 0.5)
		)

		draw_rect(cell_rect, FLOOR_COLOR)

	# Draw one red dot for every living enemy within range.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue

		if not enemy is Node3D:
			continue

		var enemy_node := enemy as Node3D

		if enemy_node.is_queued_for_deletion():
			continue

		var distance := Vector2(
			enemy_node.global_position.x - player.global_position.x,
			enemy_node.global_position.z - player.global_position.z
		).length()

		if distance > enemy_detection_radius:
			continue

		var enemy_position := _world_to_map(
			enemy_node.global_position
		)

		if inner_rect.has_point(enemy_position):
			draw_circle(enemy_position, 4.0, ENEMY_COLOR)
			draw_arc(
				enemy_position,
				4.0,
				0.0,
				TAU,
				16,
				Color("#ffb8b8"),
				1.0
			)

	# Fixed crosshair over the map.
	draw_line(
		Vector2(center.x, inner_rect.position.y),
		Vector2(center.x, inner_rect.end.y),
		CROSSHAIR_COLOR,
		1.0
	)
	draw_line(
		Vector2(inner_rect.position.x, center.y),
		Vector2(inner_rect.end.x, center.y),
		CROSSHAIR_COLOR,
		1.0
	)

	# North indicator: fixed at the top unless map rotation is enabled.
	var north_direction := Vector2.UP

	if rotate_minimap:
		var world_north := Vector3(0.0, 0.0, -1.0)
		north_direction = Vector2(
			world_north.dot(player.global_basis.x),
			world_north.dot(player.global_basis.z)
		).normalized()

	var north_position := center + north_direction * (map_size * 0.36)
	var arrow_tip := north_position + north_direction * 8.0
	var arrow_base := north_position - north_direction * 5.0
	var side := Vector2(-north_direction.y, north_direction.x) * 5.0

	draw_colored_polygon(
		PackedVector2Array([
			arrow_tip,
			arrow_base + side,
			arrow_base - side
		]),
		Color.WHITE
	)

	draw_string(
		ThemeDB.fallback_font,
		north_position - Vector2(4.0, -15.0),
		"N",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		Color.WHITE
	)

	# Player marker stays centered and does not rotate.
	draw_circle(center, 6.0, PLAYER_COLOR)
	draw_arc(center, 6.0, 0.0, TAU, 20, Color.WHITE, 1.5)
