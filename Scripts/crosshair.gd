
extends Control

@export var crosshair_size: float = 24.0
@export var gap: float = 5.0
@export var line_width: float = 2.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(crosshair_size, crosshair_size)

func _process(_delta: float) -> void:
	position = get_viewport().get_mouse_position() - size / 2.0
	queue_redraw()

func _draw() -> void:
	var center := size / 2.0
	var color := Color.WHITE
	var outline := Color.BLACK

	# Black outline keeps the reticle visible against bright backgrounds.
	draw_line(Vector2(center.x, 0), Vector2(center.x, center.y - gap), outline, line_width + 2)
	draw_line(Vector2(center.x, center.y + gap), Vector2(center.x, size.y), outline, line_width + 2)
	draw_line(Vector2(0, center.y), Vector2(center.x - gap, center.y), outline, line_width + 2)
	draw_line(Vector2(center.x + gap, center.y), Vector2(size.x, center.y), outline, line_width + 2)

	draw_line(Vector2(center.x, 0), Vector2(center.x, center.y - gap), color, line_width)
	draw_line(Vector2(center.x, center.y + gap), Vector2(center.x, size.y), color, line_width)
	draw_line(Vector2(0, center.y), Vector2(center.x - gap, center.y), color, line_width)
	draw_line(Vector2(center.x + gap, center.y), Vector2(size.x, center.y), color, line_width)
