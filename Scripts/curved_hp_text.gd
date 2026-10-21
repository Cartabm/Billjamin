@tool
extends Control

@export var hp_current: int = 50:
	set(value):
		hp_current = value
		queue_redraw()

@export var hp_max: int = 100:
	set(value):
		hp_max = max(1, value)
		queue_redraw()

@export var font: Font
@export var font_size: int = 23

@export var arc_center_y: float = 72.0
@export var arc_rise: float = 0.00065

@export var filled_text_color: Color = Color("#fff2a8")
@export var empty_text_color: Color = Color("#66efff")
@export var outline_color: Color = Color("#101018")
@export var outline_size: int = 3


func _draw() -> void:
	if font == null:
		return

	var text_value := "%d/%d" % [hp_current, hp_max]
	var total_width := font.get_string_size(
		text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
	).x

	var start_x := (size.x - total_width) * 0.5
	var fill_boundary := size.x * clampf(
		float(hp_current) / float(hp_max), 0.0, 1.0
	)

	var cursor_x := start_x

	for character in text_value:
		var char_width := font.get_string_size(
			character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
		).x

		var center_x := cursor_x + char_width * 0.5
		var distance := center_x - size.x * 0.5

		# Raise text near the middle to match the health bar arc.
		var curve_y := arc_center_y + arc_rise * distance * distance

		var baseline := Vector2(cursor_x, curve_y)

		# Split individual glyphs at the health fill boundary.
		draw_set_transform(Vector2.ZERO)
		draw_char_outline(
			font, baseline, character, font_size,
			outline_size, outline_color
		)

		var left_color := filled_text_color
		var right_color := empty_text_color

		if center_x <= fill_boundary:
			draw_char(font, baseline, character, font_size, left_color)
		else:
			draw_char(font, baseline, character, font_size, right_color)

		cursor_x += char_width
