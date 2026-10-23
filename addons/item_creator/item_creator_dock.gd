@tool
extends VBoxContainer

const DATA_DIR := "res://Items/Data"
const ITEM_SCRIPT := "res://Items/ItemData.gd"
const STAT_SCRIPT := "res://Items/ItemStat.gd"
const RANGE_SCRIPT := "res://Items/ItemStatRange.gd"
const ROLLER_SCRIPT := "res://Items/ItemRoller.gd"
const QUALITY_MULTIPLIERS := {"Common": 1.0, "Uncommon": 1.3, "Rare": 1.7, "Epic": 2.3, "Legendary": 3.2, "Mythic": 4.5}
const TYPES := ["Body Armor", "One-Handed Weapon", "Two-Handed Weapon", "Helmet", "Gloves", "Boots", "Shield", "Ring", "Amulet", "Belt", "Consumable", "Miscellaneous"]
const DEFAULT_SIZES := {
	"Body Armor": Vector2i(2, 6),
	"One-Handed Weapon": Vector2i(1, 3),
	"Two-Handed Weapon": Vector2i(2, 5),
	"Helmet": Vector2i(2, 2),
	"Gloves": Vector2i(2, 2),
	"Boots": Vector2i(2, 2),
	"Shield": Vector2i(2, 4),
	"Ring": Vector2i(1, 1),
	"Amulet": Vector2i(1, 1),
	"Belt": Vector2i(2, 1),
	"Consumable": Vector2i(1, 1),
	"Miscellaneous": Vector2i(1, 1)
}
const QUALITIES := ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic"]

# Approved item stats, independent of whether player combat has implemented them yet.
# Add new stats here when your game design calls for them. Saving these values does
# NOT automatically equip them or make them affect combat.
const STATS := {
	"Core Attributes": {"strength": "Strength", "dexterity": "Dexterity", "intelligence": "Intelligence"},
	"Offense": {"min_damage": "Minimum Damage", "max_damage": "Maximum Damage", "crit_chance": "Critical Chance (%)", "crit_damage": "Critical Damage (%)", "attack_speed": "Attack Speed (%)"},
	"Elemental": {"fire_damage": "Fire Damage", "cold_damage": "Cold Damage", "lightning_damage": "Lightning Damage", "poison_damage": "Poison Damage"},
	"Defense": {"armor": "Armor", "max_health": "Maximum Health", "damage_reduction": "Damage Reduction (%)", "fire_resistance": "Fire Resistance (%)", "cold_resistance": "Cold Resistance (%)", "lightning_resistance": "Lightning Resistance (%)", "poison_resistance": "Poison Resistance (%)"},
	"Utility": {"move_speed": "Movement Speed (%)", "projectile_count": "Additional Projectiles", "projectile_speed": "Projectile Speed (%)", "xp_gain": "Experience Gain (%)"}
}

var name_edit: LineEdit
var description_edit: TextEdit
var type_option: OptionButton
var quality_option: OptionButton
var width_spin: SpinBox
var height_spin: SpinBox
var icon_area: ItemIconDropArea
var icon_preview: TextureRect
var icon_texture: Texture2D
var preview_title: Label
var preview_type: Label
var preview_stats: Label
var rows_box: VBoxContainer
var stat_rows: Array[Dictionary] = []
var current_edit_quality: String = "Common"
var auto_fill_confirmation: ConfirmationDialog
var roll_preview_label: Label
var existing_option: OptionButton
var status_label: Label
var editing_label: Label
var loaded_path := ""
var confirm_save: ConfirmationDialog

func _ready() -> void:
	custom_minimum_size = Vector2(330, 0)
	_build_ui()
	_reset_form(false)
	_refresh_files()

func _heading(parent: Node, title_text: String) -> void:
	var lbl := Label.new()
	lbl.text = title_text
	parent.add_child(lbl)

func _button(parent: Node, label_text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = label_text
	parent.add_child(btn)
	btn.pressed.connect(callback)
	return btn

func _spin(parent: Node, minimum: float, maximum: float, step_value: float, initial: float) -> SpinBox:
	var sp := SpinBox.new()
	sp.min_value = minimum
	sp.max_value = maximum
	sp.step = step_value
	sp.value = initial
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sp)
	return sp

func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	_heading(body, "Item Creator")
	var intro := Label.new()
	intro.text = "Create item templates with quality-based random stat ranges. Loot and equipping will be connected later."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(intro)
	_heading(body, "Existing Item")
	existing_option = OptionButton.new()
	body.add_child(existing_option)
	var load_buttons := HBoxContainer.new()
	body.add_child(load_buttons)
	_button(load_buttons, "Load Selected", _load_selected)
	_button(load_buttons, "+ New Item", func() -> void: _reset_form(true))
	editing_label = Label.new()
	editing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(editing_label)
	body.add_child(HSeparator.new())
	_heading(body, "Item Name")
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Type new item name here"
	body.add_child(name_edit)
	name_edit.text_changed.connect(func(_value: String) -> void: _update_preview())
	_heading(body, "Description")
	description_edit = TextEdit.new()
	description_edit.placeholder_text = "Enter item description here"
	description_edit.custom_minimum_size.y = 70
	body.add_child(description_edit)
	_heading(body, "Item Type")
	type_option = OptionButton.new()
	for item_type in TYPES:
		type_option.add_item(item_type)
	body.add_child(type_option)
	type_option.item_selected.connect(_type_changed)
	_heading(body, "Inventory Size (grid cells)")
	var size_row := HBoxContainer.new()
	body.add_child(size_row)
	_heading(size_row, "Width")
	width_spin = _spin(size_row, 1, 20, 1, 2)
	_heading(size_row, "Height")
	height_spin = _spin(size_row, 1, 20, 1, 6)
	width_spin.value_changed.connect(func(_v: float) -> void: _update_preview())
	height_spin.value_changed.connect(func(_v: float) -> void: _update_preview())
	_heading(body, "Quality")
	quality_option = OptionButton.new()
	for quality in QUALITIES:
		quality_option.add_item(quality)
	body.add_child(quality_option)
	quality_option.item_selected.connect(_quality_changed)
	var quality_help := Label.new()
	quality_help.text = "Select a quality to edit its stat ranges. Every quality is saved in the same item."
	quality_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(quality_help)
	_heading(body, "Icon — drag a PNG from FileSystem")
	icon_area = ItemIconDropArea.new()
	icon_area.custom_minimum_size = Vector2(0, 115)
	body.add_child(icon_area)
	var icon_box := CenterContainer.new()
	icon_area.add_child(icon_box)
	icon_preview = TextureRect.new()
	icon_preview.custom_minimum_size = Vector2(96, 96)
	icon_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_box.add_child(icon_preview)
	icon_area.icon_dropped.connect(func(texture: Texture2D) -> void:
		icon_texture = texture
		icon_preview.texture = texture
	)
	_button(body, "Clear Icon", func() -> void:
		icon_texture = null
		icon_preview.texture = null
	)
	_heading(body, "Item Preview")
	var preview_panel := PanelContainer.new()
	body.add_child(preview_panel)
	var preview_box := VBoxContainer.new()
	preview_panel.add_child(preview_box)
	preview_title = Label.new()
	preview_box.add_child(preview_title)
	preview_type = Label.new()
	preview_box.add_child(preview_type)
	preview_stats = Label.new()
	preview_box.add_child(preview_stats)
	_heading(body, "Item Attributes")
	var help := Label.new()
	help.text = "Set Min and Max for each attribute at the selected quality. Switch Quality to edit other tiers. Rolls happen later when an item drops."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(help)
	rows_box = VBoxContainer.new()
	body.add_child(rows_box)
	_button(body, "+ Add Attribute", _add_stat_row)
	_button(body, "Auto-fill higher qualities from Common...", _request_auto_fill)
	var auto_fill_help := Label.new()
	auto_fill_help.text = "Optional: generates higher-tier ranges from Common. You can edit any tier afterward."
	auto_fill_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(auto_fill_help)
	_button(body, "Roll Test Item (preview only)", _roll_preview)
	roll_preview_label = Label.new()
	roll_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(roll_preview_label)
	body.add_child(HSeparator.new())
	_button(body, "Create Item", _create_item)
	_button(body, "Save Changes to Loaded Item", _request_save)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(status_label)
	confirm_save = ConfirmationDialog.new()
	confirm_save.title = "Confirm Item Changes"
	add_child(confirm_save)
	confirm_save.confirmed.connect(_save_loaded)
	auto_fill_confirmation = ConfirmationDialog.new()
	auto_fill_confirmation.title = "Auto-fill Quality Ranges"
	auto_fill_confirmation.dialog_text = "Replace ALL Uncommon–Mythic ranges with scaled Common ranges?\n\nExisting higher-tier values will be overwritten."
	add_child(auto_fill_confirmation)
	auto_fill_confirmation.confirmed.connect(_auto_fill_from_common)

func _type_changed(index: int) -> void:
	var item_type := type_option.get_item_text(index)
	var footprint: Vector2i = DEFAULT_SIZES.get(item_type, Vector2i(1, 1))
	width_spin.value = footprint.x
	height_spin.value = footprint.y
	_update_preview()

func _new_ranges(value: float = 0.0) -> Dictionary:
	var ranges := {}
	for quality in QUALITIES:
		ranges[quality] = Vector2(value, value)
	return ranges

func _commit_quality_rows(quality: String) -> void:
	for row in stat_rows:
		var minimum: SpinBox = row["minimum"]
		var maximum: SpinBox = row["maximum"]
		var ranges: Dictionary = row["ranges"]
		ranges[quality] = Vector2(minimum.value, maximum.value)

func _load_quality_rows(quality: String) -> void:
	for row in stat_rows:
		var bounds: Vector2 = row["ranges"].get(quality, Vector2.ZERO)
		(row["minimum"] as SpinBox).value = bounds.x
		(row["maximum"] as SpinBox).value = bounds.y

func _quality_changed(index: int) -> void:
	_commit_quality_rows(current_edit_quality)
	current_edit_quality = quality_option.get_item_text(index)
	_load_quality_rows(current_edit_quality)
	_update_preview()

func _add_stat_row(stat_id: String = "", value: float = 0.0, supplied_ranges: Dictionary = {}) -> void:
	var panel := PanelContainer.new()
	rows_box.add_child(panel)
	var content := VBoxContainer.new()
	panel.add_child(content)
	var top := HBoxContainer.new()
	content.add_child(top)
	var category := OptionButton.new()
	category.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for category_name in STATS.keys():
		category.add_item(category_name)
	top.add_child(category)
	var remove := _button(top, "Remove", func() -> void:
		for i in range(stat_rows.size()):
			if stat_rows[i]["panel"] == panel:
				stat_rows.remove_at(i)
				break
		panel.queue_free()
		_update_preview()
	)
	remove.tooltip_text = "Remove this attribute from the item"
	var attribute := OptionButton.new()
	attribute.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(attribute)
	var range_line := HBoxContainer.new()
	content.add_child(range_line)
	_heading(range_line, "Min")
	var minimum := _spin(range_line, -1000000, 1000000, 1.0, value)
	_heading(range_line, "Max")
	var maximum := _spin(range_line, -1000000, 1000000, 1.0, value)
	var ranges := _new_ranges(value)
	for quality in supplied_ranges.keys():
		if QUALITIES.has(quality):
			ranges[quality] = supplied_ranges[quality]
	var row := {"panel": panel, "category": category, "attribute": attribute, "minimum": minimum, "maximum": maximum, "ranges": ranges}
	stat_rows.append(row)
	var chosen_category := ""
	for category_name in STATS.keys():
		if STATS[category_name].has(stat_id):
			chosen_category = category_name
			break
	if not chosen_category.is_empty():
		for i in range(category.item_count):
			if category.get_item_text(i) == chosen_category:
				category.select(i)
				break
	_refresh_attribute(row)
	if not stat_id.is_empty():
		for i in range(attribute.item_count):
			if String(attribute.get_item_metadata(i)) == stat_id:
				attribute.select(i)
				break
	var initial_bounds: Vector2 = ranges[current_edit_quality]
	minimum.value = initial_bounds.x
	maximum.value = initial_bounds.y
	category.item_selected.connect(func(_index: int) -> void:
		_refresh_attribute(row)
		_update_preview()
	)
	attribute.item_selected.connect(func(_index: int) -> void: _update_preview())
	minimum.value_changed.connect(func(_number: float) -> void: _update_preview())
	maximum.value_changed.connect(func(_number: float) -> void: _update_preview())
	_update_preview()

func _request_auto_fill() -> void:
	auto_fill_confirmation.popup_centered()

func _auto_fill_from_common() -> void:
	_commit_quality_rows(current_edit_quality)
	for row in stat_rows:
		var ranges: Dictionary = row["ranges"]
		var common: Vector2 = ranges["Common"]
		for quality in QUALITIES:
			var multiplier: float = QUALITY_MULTIPLIERS[quality]
			ranges[quality] = Vector2(roundf(common.x * multiplier), roundf(common.y * multiplier))
	_load_quality_rows(current_edit_quality)
	_update_preview()
	_set_status("Filled quality ranges from Common. Review them before saving.", false)

func _roll_preview() -> void:
	if not _validate():
		return
	var item_script := load(ITEM_SCRIPT) as Script
	if item_script == null:
		_set_status("Item rolling scripts missing.", true)
		return
	var temporary: Resource = item_script.new()
	if not _apply_form(temporary):
		return
	var rolled: ItemRoll = ItemRoller.roll_item(temporary, current_edit_quality)
	if rolled == null:
		_set_status("Could not roll preview.", true)
		return
	var lines: Array[String] = ["Random %s roll (preview only):" % current_edit_quality]
	for stat_id in rolled.rolled_stats.keys():
		lines.append("%s: %s" % [_stat_label(String(stat_id)), str(rolled.rolled_stats[stat_id])])
	roll_preview_label.text = "\n".join(lines)
	roll_preview_label.add_theme_color_override("font_color", ItemQuality.get_name_color(current_edit_quality))

func _refresh_attribute(row: Dictionary) -> void:
	var category: OptionButton = row["category"]
	var attribute: OptionButton = row["attribute"]
	attribute.clear()
	var category_name := category.get_item_text(category.selected)
	var catalog: Dictionary = STATS[category_name]
	for stat_id in catalog.keys():
		var idx := attribute.item_count
		attribute.add_item(String(catalog[stat_id]))
		attribute.set_item_metadata(idx, stat_id)
	if attribute.item_count > 0:
		attribute.select(0)

func _stat_label(stat_id: String) -> String:
	for category_name in STATS.keys():
		if STATS[category_name].has(stat_id):
			return String(STATS[category_name][stat_id])
	return stat_id

func _update_preview() -> void:
	if preview_title == null:
		return
	var item_title := name_edit.text.strip_edges()
	preview_title.text = item_title if not item_title.is_empty() else "New Item"
	var quality := quality_option.get_item_text(quality_option.selected)
	preview_title.add_theme_color_override("font_color", ItemQuality.get_name_color(quality))
	quality_option.add_theme_color_override("font_color", ItemQuality.get_name_color(quality))
	quality_option.add_theme_color_override("font_hover_color", ItemQuality.get_name_color(quality))
	preview_type.text = "%s • %s • %dx%d cells" % [quality, type_option.get_item_text(type_option.selected), int(width_spin.value), int(height_spin.value)]
	var stat_lines: Array[String] = []
	for row in stat_rows:
		var attribute: OptionButton = row["attribute"]
		if attribute.item_count == 0 or attribute.selected < 0:
			continue
		var stat_id := String(attribute.get_item_metadata(attribute.selected))
		var minimum: SpinBox = row["minimum"]
		var maximum: SpinBox = row["maximum"]
		stat_lines.append("%s: %s–%s" % [_stat_label(stat_id), str(minimum.value), str(maximum.value)])
	preview_stats.text = "\n".join(stat_lines) if not stat_lines.is_empty() else "No attributes yet"

func _get_specs() -> Array[Dictionary]:
	_commit_quality_rows(current_edit_quality)
	var specs: Array[Dictionary] = []
	var seen: Dictionary = {}
	for row in stat_rows:
		var attribute: OptionButton = row["attribute"]
		if attribute.item_count == 0 or attribute.selected < 0:
			_set_status("Choose an attribute in every row.", true)
			return []
		var stat_id := String(attribute.get_item_metadata(attribute.selected))
		if seen.has(stat_id):
			_set_status("Attribute selected twice: " + _stat_label(stat_id) + ". Remove the duplicate.", true)
			return []
		seen[stat_id] = true
		var ranges: Dictionary = row["ranges"].duplicate()
		for quality in QUALITIES:
			var bounds: Vector2 = ranges.get(quality, Vector2.ZERO)
			if bounds.x > bounds.y:
				_set_status("%s: %s Min must not exceed Max." % [_stat_label(stat_id), quality], true)
				return []
		specs.append({"stat_id": stat_id, "ranges": ranges})
	return specs

func _validate() -> bool:
	if name_edit.text.strip_edges().is_empty():
		_set_status("Enter an item name first.", true)
		return false
	if stat_rows.size() > 0 and _get_specs().size() != stat_rows.size():
		return false
	return true

func _apply_form(resource: Resource) -> bool:
	if not _validate():
		return false
	var stat_script := load(STAT_SCRIPT) as Script
	if stat_script == null:
		_set_status("Missing Items/ItemStat.gd", true)
		return false
	var range_script := load(RANGE_SCRIPT) as Script
	if range_script == null:
		_set_status("Missing Items/ItemStatRange.gd", true)
		return false
	var typed_stats: Array[ItemStat] = []
	for spec in _get_specs():
		var stat: ItemStat = stat_script.new()
		stat.stat_id = String(spec["stat_id"])
		var ranges: Dictionary = spec["ranges"]
		var common: Vector2 = ranges["Common"]
		stat.value = common.x # Backwards-compatible legacy field
		var typed_ranges: Array[ItemStatRange] = []
		for quality in QUALITIES:
			var bounds: Vector2 = ranges[quality]
			var entry: ItemStatRange = range_script.new()
			entry.quality = quality
			entry.min_value = bounds.x
			entry.max_value = bounds.y
			typed_ranges.append(entry)
		stat.quality_ranges = typed_ranges
		typed_stats.append(stat)
	resource.set("item_name", name_edit.text.strip_edges())
	resource.set("description", description_edit.text)
	resource.set("icon", icon_texture)
	resource.set("item_type", type_option.get_item_text(type_option.selected))
	resource.set("grid_width", int(width_spin.value))
	resource.set("grid_height", int(height_spin.value))
	resource.set("quality", quality_option.get_item_text(quality_option.selected))
	resource.set("stats", typed_stats)
	return true

func _slug(value: String) -> String:
	var output := ""
	for ch in value.to_lower():
		if ch in "abcdefghijklmnopqrstuvwxyz0123456789":
			output += ch
		elif output.length() > 0 and not output.ends_with("_"):
			output += "_"
	return output.trim_suffix("_")

func _create_item() -> void:
	if not _validate():
		return
	var item_script := load(ITEM_SCRIPT) as Script
	if item_script == null:
		_set_status("Missing Items/ItemData.gd", true)
		return
	var slug := _slug(name_edit.text.strip_edges())
	if slug.is_empty():
		_set_status("Use a name containing letters or numbers.", true)
		return
	var path := DATA_DIR.path_join(slug + ".tres")
	if FileAccess.file_exists(path):
		_set_status("An item with this filename already exists. Load it to edit; nothing overwritten.", true)
		return
	var data: Resource = item_script.new()
	if not _apply_form(data):
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DATA_DIR))
	var err := ResourceSaver.save(data, path)
	if err != OK:
		_set_status("Could not save item. Error: " + str(err), true)
		return
	EditorInterface.get_resource_filesystem().scan()
	loaded_path = path
	_refresh_files()
	_update_mode()
	_set_status("Created: " + path, false)

func _refresh_files() -> void:
	existing_option.clear()
	var directory := DirAccess.open(DATA_DIR)
	if directory == null:
		return
	var filenames: Array[String] = []
	for filename in directory.get_files():
		if filename.ends_with(".tres"):
			filenames.append(filename)
	filenames.sort()
	for filename in filenames:
		var path := DATA_DIR.path_join(filename)
		var data := ResourceLoader.load(path)
		if not (data is ItemData):
			continue
		var idx := existing_option.item_count
		existing_option.add_item(String(data.get("item_name")))
		existing_option.set_item_metadata(idx, path)
		if path == loaded_path:
			existing_option.select(idx)

func _load_selected() -> void:
	if existing_option.selected < 0:
		_set_status("No saved item selected.", true)
		return
	var path := String(existing_option.get_item_metadata(existing_option.selected))
	var data := ResourceLoader.load(path)
	if not (data is ItemData):
		_set_status("Could not load item resource.", true)
		return
	name_edit.text = data.item_name
	description_edit.text = data.description
	icon_texture = data.icon
	icon_preview.texture = icon_texture
	for i in range(type_option.item_count):
		if type_option.get_item_text(i) == data.item_type:
			type_option.select(i)
			break
	width_spin.value = data.grid_width
	height_spin.value = data.grid_height
	for i in range(quality_option.item_count):
		if quality_option.get_item_text(i) == data.quality:
			quality_option.select(i)
			break
	current_edit_quality = quality_option.get_item_text(quality_option.selected)
	_clear_rows()
	for stat in data.stats:
		if stat == null:
			continue
		var found := false
		for category_name in STATS.keys():
			if STATS[category_name].has(stat.stat_id):
				found = true
				break
		if not found:
			_set_status("Cannot edit unknown attribute: " + stat.stat_id + ". No changes made.", true)
			_reset_form(false)
			return
		var saved_ranges := {}
		for entry in stat.quality_ranges:
			if entry != null and QUALITIES.has(entry.quality):
				saved_ranges[entry.quality] = Vector2(entry.min_value, entry.max_value)
		_add_stat_row(stat.stat_id, stat.value, saved_ranges)
	loaded_path = path
	_update_mode()
	_update_preview()
	_set_status("Loaded for editing. Changes are not saved until you click Save Changes.", false)

func _clear_rows() -> void:
	for row in stat_rows:
		(row["panel"] as Control).queue_free()
	stat_rows.clear()

func _reset_form(show_message: bool) -> void:
	loaded_path = ""
	name_edit.clear()
	description_edit.clear()
	icon_texture = null
	icon_preview.texture = null
	type_option.select(0)
	quality_option.select(0)
	current_edit_quality = "Common"
	width_spin.value = 2
	height_spin.value = 6
	_clear_rows()
	_add_stat_row()
	if roll_preview_label != null:
		roll_preview_label.text = ""
	_update_mode()
	_update_preview()
	if show_message:
		_set_status("Ready to create a new item. Existing items unchanged.", false)

func _update_mode() -> void:
	editing_label.text = "Editing: " + loaded_path if not loaded_path.is_empty() else "Mode: New Item"

func _request_save() -> void:
	if loaded_path.is_empty():
		_set_status("Load an existing item before saving changes.", true)
		return
	if not _validate():
		return
	confirm_save.dialog_text = "Overwrite this item definition?\n\n" + loaded_path
	confirm_save.popup_centered()

func _save_loaded() -> void:
	if loaded_path.is_empty() or not FileAccess.file_exists(loaded_path):
		_set_status("Original item file is missing. Nothing saved.", true)
		return
	var data := ResourceLoader.load(loaded_path)
	if not (data is ItemData):
		_set_status("Original item could not be loaded. Nothing saved.", true)
		return
	if not _apply_form(data):
		return
	var err := ResourceSaver.save(data, loaded_path)
	if err != OK:
		_set_status("Save failed: " + str(err), true)
		return
	EditorInterface.get_resource_filesystem().scan()
	_refresh_files()
	_set_status("Saved changes to: " + loaded_path, false)

func _set_status(message: String, is_error: bool) -> void:
	status_label.text = message
	status_label.modulate = Color(1, 0.5, 0.5) if is_error else Color(0.5, 1, 0.6)

class ItemIconDropArea extends PanelContainer:
	signal icon_dropped(texture: Texture2D)

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return not _get_path(data).is_empty()

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		var path := _get_path(data)
		if path.is_empty():
			return
		var texture := load(path) as Texture2D
		if texture != null:
			icon_dropped.emit(texture)

	func _get_path(data: Variant) -> String:
		if not (data is Dictionary) or data.get("type", "") != "files":
			return ""
		var files: PackedStringArray = data.get("files", PackedStringArray())
		if files.size() != 1:
			return ""
		var path := String(files[0])
		if path.get_extension().to_lower() not in ["png", "jpg", "jpeg", "webp", "svg"]:
			return ""
		return path
