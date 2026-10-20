extends Control

const ROOM_SIZE := 18.0
const ROOM_SPACING := 38.0
const EXIT_LENGTH := 11.0

const MAP_PADDING := 12.0
const MIN_SCALE := 0.10

var connections: Dictionary = {}
var discovered_rooms: Dictionary = {}
var current_room := Vector2i.ZERO

# Boss room support for later.
var boss_room_cell := Vector2i.ZERO
var boss_room_revealed := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func setup_map(dungeon_connections: Dictionary) -> void:
	connections = dungeon_connections.duplicate(true)
	discovered_rooms.clear()
	current_room = Vector2i.ZERO
	discovered_rooms[Vector2i.ZERO] = true

	boss_room_revealed = false

	queue_redraw()


func enter_room(cell: Vector2i) -> void:
	current_room = cell
	discovered_rooms[cell] = true
	queue_redraw()


func reveal_boss_room(cell: Vector2i, dungeon_connections: Dictionary) -> void:
	# Called when the final regular encounter is cleared.
	connections = dungeon_connections.duplicate(true)
	boss_room_cell = cell
	boss_room_revealed = true

	# Show boss location without marking it as explored.
	queue_redraw()


func _draw() -> void:
	# Background.
	draw_rect(
		Rect2(Vector2.ZERO, size),
		Color(0.0, 0.0, 0.0, 0.6)
	)

	# Border.
	draw_rect(
		Rect2(Vector2.ZERO, size),
		Color(0.5, 0.5, 0.5, 0.7),
		false,
		2.0
	)

	# Collect all visible rooms.
	var visible_cells: Array[Vector2i] = []

	for cell in discovered_rooms.keys():
		visible_cells.append(cell)

	if boss_room_revealed and not visible_cells.has(boss_room_cell):
		visible_cells.append(boss_room_cell)

	if visible_cells.is_empty():
		return

	# Find the boundaries of the discovered dungeon.
	var min_x: int = visible_cells[0].x
	var max_x: int = visible_cells[0].x
	var min_y: int = visible_cells[0].y
	var max_y: int = visible_cells[0].y

	for cell in visible_cells:
		min_x = mini(min_x, cell.x)
		max_x = maxi(max_x, cell.x)
		min_y = mini(min_y, cell.y)
		max_y = maxi(max_y, cell.y)

	# Calculate the width and height of the map layout.
	var layout_width: float = float(max_x - min_x) * ROOM_SPACING + ROOM_SIZE
	var layout_height: float = float(max_y - min_y) * ROOM_SPACING + ROOM_SIZE

	var available_width: float = maxf(1.0, size.x - MAP_PADDING * 2.0)
	var available_height: float = maxf(1.0, size.y - MAP_PADDING * 2.0)

	# Automatically shrink the map if it exceeds its boundaries.
	var scale_x: float = available_width / layout_width
	var scale_y: float = available_height / layout_height

	var map_scale: float = minf(1.0, minf(scale_x, scale_y))

	# Keep tiny dungeons from becoming impossibly small.
	# The minimum is only used if it still fits inside the window.
	if map_scale < MIN_SCALE:
		map_scale = minf(scale_x, scale_y)

	# Center the entire visible dungeon layout.
	var layout_center := Vector2(
		float(min_x + max_x) * 0.5,
		float(min_y + max_y) * 0.5
	)

	var screen_center: Vector2 = size / 2.0

	var scaled_room_size: float = ROOM_SIZE * map_scale
	var scaled_spacing: float = ROOM_SPACING * map_scale
	var scaled_exit_length: float = EXIT_LENGTH * map_scale
	var scaled_line_width: float = maxf(1.0, 3.0 * map_scale)

	# Draw all discovered rooms.
	for cell in discovered_rooms.keys():
		var room_center: Vector2 = screen_center + (
			Vector2(cell.x, cell.y) - layout_center
		) * scaled_spacing

		# Draw corridors and exits.
		if connections.has(cell):
			for direction in connections[cell]:
				var exit_direction := Vector2(
					direction.x,
					direction.y
				)

				var start: Vector2 = room_center + exit_direction * (
					scaled_room_size / 2.0
				)

				var neighbor: Vector2i = cell + direction
				var line_length: float = scaled_exit_length

				if discovered_rooms.has(neighbor):
					line_length = scaled_spacing - scaled_room_size
				elif boss_room_revealed and neighbor == boss_room_cell:
					line_length = scaled_spacing - scaled_room_size

				var finish: Vector2 = start + exit_direction * line_length

				draw_line(
					start,
					finish,
					Color("#B8A47A"),
					scaled_line_width
				)

		# Current room is gold.
		var room_color := Color("#777777")

		if cell == current_room:
			room_color = Color("#D4B878")

		var room_rect := Rect2(
			room_center - Vector2.ONE * scaled_room_size / 2.0,
			Vector2.ONE * scaled_room_size
		)

		draw_rect(room_rect, room_color)

	# Draw boss room as a red square.
	if boss_room_revealed:
		var boss_center: Vector2 = screen_center + (
			Vector2(boss_room_cell.x, boss_room_cell.y) - layout_center
		) * scaled_spacing

		var boss_rect := Rect2(
			boss_center - Vector2.ONE * scaled_room_size / 2.0,
			Vector2.ONE * scaled_room_size
		)

		draw_rect(
			boss_rect,
			Color("#D62828")
		)

		draw_rect(
			boss_rect,
			Color("#FF7777"),
			false,
			maxf(1.0, 2.0 * map_scale)
		)
