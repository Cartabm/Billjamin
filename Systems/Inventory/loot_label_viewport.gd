extends SubViewport

@onready var label_panel: PanelContainer = $LootLabelPanel
@onready var label_text: Label = $LootLabelPanel/LootLabelText

const NORMAL_FONT_SIZE: int = 36
const HOVER_FONT_SIZE: int = 46

const NORMAL_BG: Color = Color("#202020")
const HOVER_BG: Color = Color("#353025")

const NORMAL_TEXT: Color = Color("#eeeeee")
const HOVER_TEXT: Color = Color("#ffdc78")

const BORDER_COLOR: Color = Color("#d9a441")

var is_hovered: bool = false
var panel_style: StyleBoxFlat


func _ready() -> void:
	transparent_bg = true

	panel_style = StyleBoxFlat.new()

	panel_style.set_content_margin_all(8)
	panel_style.bg_color = NORMAL_BG

	label_panel.add_theme_stylebox_override("panel", panel_style)

	label_text.add_theme_font_size_override(
		"font_size",
		NORMAL_FONT_SIZE
	)

	label_text.add_theme_color_override(
		"font_color",
		NORMAL_TEXT
	)

	label_text.resized.connect(_update_size)

	_update_size.call_deferred()


func set_item_name(item_name: String) -> void:
	if not is_node_ready():
		await ready

	label_text.text = item_name

	_update_size.call_deferred()


func set_hovered(hovered: bool) -> void:
	if is_hovered == hovered:
		return

	is_hovered = hovered

	if hovered:
		label_text.add_theme_font_size_override(
			"font_size",
			HOVER_FONT_SIZE
		)

		label_text.add_theme_color_override(
			"font_color",
			HOVER_TEXT
		)

		panel_style.bg_color = HOVER_BG

		panel_style.border_color = BORDER_COLOR
		panel_style.set_border_width_all(2)

	else:
		label_text.add_theme_font_size_override(
			"font_size",
			NORMAL_FONT_SIZE
		)

		label_text.add_theme_color_override(
			"font_color",
			NORMAL_TEXT
		)

		panel_style.bg_color = NORMAL_BG
		panel_style.set_border_width_all(0)

	label_panel.queue_redraw()
	_update_size.call_deferred()


func _update_size() -> void:
	label_panel.reset_size()

	var new_size: Vector2 = label_panel.get_combined_minimum_size()

	size = Vector2i(
		maxi(1, ceili(new_size.x)),
		maxi(1, ceili(new_size.y))
	)
