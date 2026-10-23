extends Control
## Visual-only permanent upgrade tree mockup for The Tower of Billjamin.
## No currencies, save data, upgrades, or altar interactions are implemented.

const BG := Color("090c16")
const PANEL := Color("151b2b")
const PANEL_EDGE := Color("5c4b7e")
const MUTED := Color("a3a7b8")
const WHITE := Color("f1ebff")
const PURPLE := Color("b18cf9")
const GOLD := Color("e9c477")
const CYAN := Color("82d9d8")
const RED := Color("e6a2aa")

const BRANCHES := [
	{"name": "VIGOR", "color": RED, "nodes": ["Iron Heart", "Stone Skin", "Undying Will"]},
	{"name": "ARCANA", "color": PURPLE, "nodes": ["Ember Soul", "Runic Power", "Astral Surge"]},
	{"name": "FORTUNE", "color": CYAN, "nodes": ["Prospector", "Wanderer's Luck", "Golden Legacy"]}
]

var _panel_rect := Rect2()
var _node_buttons: Array[Button] = []
var _branch_labels: Array[Label] = []
var _node_captions: Array[Label] = []
var _title: Label
var _subtitle: Label
var _currency: Label
var _footer: Label
var _status: Label
var _close: Button
var _origin_button: Button
var _origin_caption: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_layout_ui()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_layout_ui()
		queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_U:
			visible = not visible
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and visible:
			visible = false
			get_viewport().set_input_as_handled()

func _build_ui() -> void:
	_title = _make_label("ALTAR OF ASCENDANCE", 28, WHITE)
	_subtitle = _make_label("PERMANENT UPGRADE TREE  /  VISUAL PROTOTYPE", 12, MUTED)
	_currency = _make_label("SOUL SHARDS  0", 15, GOLD)
	_currency.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_footer = _make_label("Prototype only  •  No upgrades or currency are connected", 12, MUTED)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status = _make_label("Select a blessing to preview its name.", 13, WHITE)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_close = _make_button("✕", WHITE, Color("343047"), PANEL_EDGE)
	_close.tooltip_text = "Close tree (press U to reopen)"
	_close.pressed.connect(func() -> void: visible = false)

	_origin_button = _make_button("✦", GOLD, Color("3a3040"), GOLD)
	_origin_button.tooltip_text = "The beginning of your legacy"
	_origin_button.pressed.connect(func() -> void: _status.text = "The Beginning  —  foundation of the tree (preview only)")
	_origin_caption = _make_label("The Beginning", 12, WHITE)
	_origin_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	for branch_index in range(BRANCHES.size()):
		var branch: Dictionary = BRANCHES[branch_index]
		var heading := _make_label(branch["name"], 15, branch["color"])
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_branch_labels.append(heading)
		for node_index in range(3):
			var node_name: String = branch["nodes"][node_index]
			var btn := _make_button("✦", branch["color"], Color("24243b"), branch["color"])
			btn.tooltip_text = node_name + " — placeholder, no effect"
			btn.pressed.connect(_on_node_pressed.bind(branch_index, node_index))
			_node_buttons.append(btn)
			var caption := _make_label(node_name, 12, WHITE)
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_node_captions.append(caption)

func _make_label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _make_button(value: String, font_color: Color, fill: Color, edge: Color) -> Button:
	var btn := Button.new()
	btn.text = value
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 23)
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_hover_color", WHITE)
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = fill.lightened(0.18) if state != "normal" else fill
		style.border_color = edge
		style.set_border_width_all(2)
		style.set_corner_radius_all(14)
		btn.add_theme_stylebox_override(state, style)
	add_child(btn)
	return btn

func _layout_ui() -> void:
	if _title == null:
		return
	var panel_width := minf(size.x - 24.0, 1100.0)
	var panel_height := minf(size.y - 24.0, 650.0)
	_panel_rect = Rect2((size.x - panel_width) * 0.5, (size.y - panel_height) * 0.5, panel_width, panel_height)
	var r := _panel_rect
	_place(_title, Vector2(r.position.x + 34, r.position.y + 22), Vector2(r.size.x * 0.67, 40))
	_place(_subtitle, Vector2(r.position.x + 35, r.position.y + 65), Vector2(r.size.x * 0.68, 25))
	_place(_currency, Vector2(r.end.x - 230, r.position.y + 36), Vector2(178, 28))
	_place(_close, Vector2(r.end.x - 45, r.position.y + 24), Vector2(27, 30))
	_place(_status, Vector2(r.position.x + 25, r.end.y - 84), Vector2(r.size.x - 50, 26))
	_place(_footer, Vector2(r.position.x + 25, r.end.y - 45), Vector2(r.size.x - 50, 24))

	var center := _point(0.14, 0.54)
	_place(_origin_button, center - Vector2(25, 25), Vector2(50, 50))
	_place(_origin_caption, center + Vector2(-72, 35), Vector2(144, 25))

	for b in range(3):
		var y_ratio: float = [0.31, 0.54, 0.77][b]
		_place(_branch_labels[b], _point(0.22, y_ratio) + Vector2(0, -51), Vector2(r.size.x * 0.73, 22))
		for n in range(3):
			var idx := b * 3 + n
			var center_pos := _point([0.37, 0.61, 0.84][n], y_ratio)
			_place(_node_buttons[idx], center_pos - Vector2(24, 24), Vector2(48, 48))
			_place(_node_captions[idx], center_pos + Vector2(-83, 31), Vector2(166, 25))

func _place(control: Control, at: Vector2, dimensions: Vector2) -> void:
	control.position = at
	control.size = dimensions

func _point(x_ratio: float, y_ratio: float) -> Vector2:
	return _panel_rect.position + Vector2(_panel_rect.size.x * x_ratio, _panel_rect.size.y * y_ratio)

func _draw() -> void:
	if _panel_rect.size.x <= 0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.035, 0.065, 0.92))
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = PANEL
	panel_style.border_color = PANEL_EDGE
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(16)
	draw_style_box(panel_style, _panel_rect)
	var r := _panel_rect
	draw_line(Vector2(r.position.x + 28, r.position.y + 104), Vector2(r.end.x - 28, r.position.y + 104), PANEL_EDGE, 1.0, true)
	draw_line(Vector2(r.position.x + 28, r.end.y - 103), Vector2(r.end.x - 28, r.end.y - 103), PANEL_EDGE, 1.0, true)

	var origin := _point(0.14, 0.54)
	var junction := _point(0.25, 0.54)
	draw_line(origin, junction, GOLD.darkened(0.25), 3.0, true)
	for b in range(3):
		var y_ratio: float = [0.31, 0.54, 0.77][b]
		var first := _point(0.37, y_ratio)
		var second := _point(0.61, y_ratio)
		var third := _point(0.84, y_ratio)
		var tint: Color = BRANCHES[b]["color"]
		draw_line(junction, Vector2(junction.x, first.y), tint.darkened(0.38), 3.0, true)
		draw_line(Vector2(junction.x, first.y), first, tint.darkened(0.28), 3.0, true)
		draw_line(first, second, tint.darkened(0.28), 3.0, true)
		draw_line(second, third, tint.darkened(0.28), 3.0, true)

func _on_node_pressed(branch_index: int, node_index: int) -> void:
	var branch: Dictionary = BRANCHES[branch_index]
	var node_name: String = branch["nodes"][node_index]
	_status.text = node_name + "  —  preview only; upgrades will be implemented later"
