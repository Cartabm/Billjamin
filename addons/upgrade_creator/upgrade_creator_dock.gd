@tool
extends VBoxContainer

# Upgrade Creator v0.4
# Curated attribute catalog keeps internal engine/gameplay counters out of the UI.
# Catalog entries only appear when actually present in the supported player scripts.
# When adding a new player stat, add its name/category/description here once.
# Refresh Stats then discovers it; no upgrade-specific code is required.

const ATTRIBUTE_CATEGORIES: Array[String] = [
	"Movement", "Damage & Critical", "Defense", "Projectiles", "Progression"
]

# stat_name -> {category, label, help}. The exact stat name is stored in UpgradeEffect.
# Planned stats are safe to register here: they are NOT shown until implemented.
const ATTRIBUTE_CATALOG := {
	"move_speed": {"category": "Movement", "label": "Movement Speed", "help": "How fast the character moves."},
	"dodge_speed": {"category": "Movement", "label": "Dodge Speed", "help": "How quickly the character moves while dodging."},
	"dodge_duration": {"category": "Movement", "label": "Dodge Duration", "help": "How long each dodge lasts, in seconds."},
	"critical_hit_chance": {"category": "Damage & Critical", "label": "Critical Hit Chance", "help": "Chance of landing a critical hit. Check whether your game uses 0–1 or 0–100."},
	"critical_damage_multiplier": {"category": "Damage & Critical", "label": "Critical Damage Multiplier", "help": "Multiplier applied to critical-hit damage."},
	"minimum_damage_multiplier": {"category": "Damage & Critical", "label": "Minimum Damage Multiplier", "help": "Multiplier for the minimum damage roll."},
	"maximum_damage_multiplier": {"category": "Damage & Critical", "label": "Maximum Damage Multiplier", "help": "Multiplier for the maximum damage roll."},
	"attack_range_multiplier": {"category": "Damage & Critical", "label": "Attack Range Multiplier", "help": "Scales attack range."},
	"fire_rate": {"category": "Damage & Critical", "label": "Fire Interval", "help": "Time between attacks; a LOWER value means faster attacks."},
	"max_health": {"category": "Defense", "label": "Maximum Health", "help": "Maximum hit points. Existing health may need separate handling."},
	"damage_reduction": {"category": "Defense", "label": "Damage Reduction", "help": "Damage reduction amount; check the expected range in player code."},
	"dodge_cooldown": {"category": "Defense", "label": "Dodge Cooldown", "help": "Seconds before dodge becomes available again; lower is faster."},
	"projectile_damage": {"category": "Projectiles", "label": "Projectile Damage", "help": "Damage dealt by each projectile."},
	"multishot_count": {"category": "Projectiles", "label": "Projectile Count", "help": "Number of projectiles fired per attack."},
	"ricochet_stacks": {"category": "Projectiles", "label": "Ricochet Count", "help": "Number of ricochets, if supported by the character."},
	"xp_multiplier": {"category": "Progression", "label": "Experience Gain Multiplier", "help": "Scales experience gained."},
	# Future attributes: these remain hidden until added to character scripts.
	"strength": {"category": "Damage & Critical", "label": "Strength", "help": "Future attribute. Appears only after implementation."},
	"dexterity": {"category": "Damage & Critical", "label": "Dexterity", "help": "Future attribute. Appears only after implementation."},
	"intelligence": {"category": "Damage & Critical", "label": "Intelligence", "help": "Future attribute. Appears only after implementation."},
	"min_damage": {"category": "Damage & Critical", "label": "Minimum Damage", "help": "Future attribute. Appears only after implementation."},
	"max_damage": {"category": "Damage & Critical", "label": "Maximum Damage", "help": "Future attribute. Appears only after implementation."},
	"fire_damage": {"category": "Damage & Critical", "label": "Fire Damage", "help": "Future attribute. Requires fire damage gameplay."},
	"cold_damage": {"category": "Damage & Critical", "label": "Cold Damage", "help": "Future attribute. Requires cold damage gameplay."},
	"lightning_damage": {"category": "Damage & Critical", "label": "Lightning Damage", "help": "Future attribute. Requires lightning damage gameplay."},
	"poison_damage": {"category": "Damage & Critical", "label": "Poison Damage", "help": "Future attribute. Requires poison damage gameplay."},
	"projectile_speed": {"category": "Projectiles", "label": "Projectile Speed", "help": "Future attribute. Requires projectile system support."},
	"projectile_pierce": {"category": "Projectiles", "label": "Projectile Pierce", "help": "Future attribute. Requires projectile system support."}
}

const OUTPUT_DIRECTORY := "res://Upgrades/Data"
const CHARACTER_MANAGER_AUTOLOAD := "autoload/CharacterManager"
const FALLBACK_CLASSES := [
	{"name": "archer", "path": "res://Scenes/player.tscn", "tags": ["ranged", "physical"]},
	{"name": "rogue", "path": "res://Scenes/RoguePlayer.tscn", "tags": ["melee", "physical"]}
]

var name_edit: LineEdit
var description_edit: TextEdit
var icon_drop: IconDropArea
var icon_preview: TextureRect
var icon_hint: Label
var icon_texture: Texture2D
var melee_check: CheckBox
var ranged_check: CheckBox
var physical_check: CheckBox
var magical_check: CheckBox
var max_stacks_spin: SpinBox
var effects_container: VBoxContainer
var stat_info_label: Label
var status_label: Label
var existing_option: OptionButton
var loaded_path_label: Label
var save_button: Button
var loaded_upgrade_path: String = ""
var save_confirmation: ConfirmationDialog

# Each entry: {"name": String, "tags": Array[String], "stats": Array[String]}
var discovered_classes: Array[Dictionary] = []
# Each entry: {"panel": Control, "category": OptionButton, "stat": OptionButton, "operation": OptionButton,
#              "value": SpinBox, "remove": Button}
var effect_rows: Array[Dictionary] = []


func _ready() -> void:
	custom_minimum_size = Vector2(300, 0)
	_build_ui()
	_discover_player_stats()
	_add_effect_row()
	_refresh_existing_upgrades()
	_update_edit_mode()


func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var fields := VBoxContainer.new()
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.add_theme_constant_override("separation", 9)
	scroll.add_child(fields)

	_add_heading(fields, "Upgrade Creator")
	_add_label(fields, "Edit an existing upgrade (optional)")
	var existing_row := HBoxContainer.new()
	fields.add_child(existing_row)
	existing_option = OptionButton.new()
	existing_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	existing_row.add_child(existing_option)
	var load_button := Button.new()
	load_button.text = "Load"
	load_button.tooltip_text = "Load the selected upgrade into the form. Nothing is saved yet."
	load_button.pressed.connect(_load_selected_upgrade)
	existing_row.add_child(load_button)
	var refresh_upgrades_button := Button.new()
	refresh_upgrades_button.text = "Refresh List"
	refresh_upgrades_button.pressed.connect(_refresh_existing_upgrades)
	fields.add_child(refresh_upgrades_button)
	var new_button := Button.new()
	new_button.text = "+ New Upgrade (Clear Form)"
	new_button.pressed.connect(_reset_for_new_upgrade)
	fields.add_child(new_button)
	loaded_path_label = Label.new()
	loaded_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fields.add_child(loaded_path_label)
	_add_label(fields, "Upgrade name")
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Type new upgrade name here"
	fields.add_child(name_edit)

	_add_label(fields, "Description")
	description_edit = TextEdit.new()
	description_edit.custom_minimum_size.y = 76
	description_edit.placeholder_text = "Enter upgrade description here"
	fields.add_child(description_edit)

	_add_label(fields, "Icon (optional) — drag an image from FileSystem")
	icon_drop = IconDropArea.new()
	icon_drop.custom_minimum_size.y = 106
	icon_drop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.add_child(icon_drop)
	icon_drop.icon_dropped.connect(_on_icon_dropped)

	var icon_center := CenterContainer.new()
	icon_drop.add_child(icon_center)
	icon_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var icon_contents := VBoxContainer.new()
	icon_center.add_child(icon_contents)
	icon_preview = TextureRect.new()
	icon_preview.custom_minimum_size = Vector2(48, 48)
	icon_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_contents.add_child(icon_preview)
	icon_hint = Label.new()
	icon_hint.text = "Drop PNG / WEBP / JPG here"
	icon_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_contents.add_child(icon_hint)

	_add_label(fields, "Who can receive this? (no checks = any class)")
	var tag_row := HFlowContainer.new()
	fields.add_child(tag_row)
	melee_check = _make_checkbox(tag_row, "melee")
	ranged_check = _make_checkbox(tag_row, "ranged")
	physical_check = _make_checkbox(tag_row, "physical")
	magical_check = _make_checkbox(tag_row, "magical")
	for checkbox in [melee_check, ranged_check, physical_check, magical_check]:
		checkbox.toggled.connect(_refresh_stat_dropdowns.unbind(1))

	_add_label(fields, "Maximum stacks")
	max_stacks_spin = SpinBox.new()
	max_stacks_spin.min_value = 1
	max_stacks_spin.max_value = 100
	max_stacks_spin.step = 1
	max_stacks_spin.value = 1
	fields.add_child(max_stacks_spin)

	var effects_header := HBoxContainer.new()
	fields.add_child(effects_header)
	var effects_heading := Label.new()
	effects_heading.text = "Effects"
	effects_heading.add_theme_font_size_override("font_size", 17)
	effects_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effects_header.add_child(effects_heading)
	var refresh_button := Button.new()
	refresh_button.text = "Refresh Stats"
	refresh_button.tooltip_text = "Rescan character scripts for implemented, approved attributes"
	refresh_button.pressed.connect(_on_refresh_stats)
	effects_header.add_child(refresh_button)

	stat_info_label = Label.new()
	stat_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fields.add_child(stat_info_label)

	effects_container = VBoxContainer.new()
	effects_container.add_theme_constant_override("separation", 8)
	fields.add_child(effects_container)

	var add_effect_button := Button.new()
	add_effect_button.text = "+ Add Effect"
	add_effect_button.pressed.connect(_add_effect_row)
	fields.add_child(add_effect_button)

	var help_label := Label.new()
	help_label.text = "Multiply by 1.15 = +15%  |  Add 5 = +5  |  Set to 10 = 10"
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fields.add_child(help_label)

	var create_button := Button.new()
	create_button.text = "Create Upgrade"
	create_button.custom_minimum_size.y = 40
	create_button.pressed.connect(_create_upgrade)
	fields.add_child(create_button)

	save_button = Button.new()
	save_button.text = "Save Changes to Loaded Upgrade"
	save_button.custom_minimum_size.y = 40
	save_button.pressed.connect(_request_save_changes)
	fields.add_child(save_button)

	save_confirmation = ConfirmationDialog.new()
	save_confirmation.title = "Confirm Upgrade Changes"
	save_confirmation.confirmed.connect(_save_loaded_upgrade)
	add_child(save_confirmation)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fields.add_child(status_label)


func _add_heading(parent: Control, heading: String) -> void:
	var label := Label.new()
	label.text = heading
	label.add_theme_font_size_override("font_size", 17)
	parent.add_child(label)


func _add_label(parent: Control, label_text: String) -> void:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)


func _make_checkbox(parent: Control, title: String) -> CheckBox:
	var checkbox := CheckBox.new()
	checkbox.text = title
	parent.add_child(checkbox)
	return checkbox


func _add_effect_row() -> void:
	var panel := PanelContainer.new()
	effects_container.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)

	var heading := HBoxContainer.new()
	column.add_child(heading)
	var label := Label.new()
	label.text = "Effect " + str(effect_rows.size() + 1)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(label)
	var remove_button := Button.new()
	remove_button.text = "Remove"
	remove_button.tooltip_text = "Remove this effect"
	heading.add_child(remove_button)

	_add_label(column, "Attribute category")
	var category_option := OptionButton.new()
	for category_name in ATTRIBUTE_CATEGORIES:
		category_option.add_item(category_name)
	category_option.select(0)
	column.add_child(category_option)

	_add_label(column, "Player attribute")
	var stat_option := OptionButton.new()
	stat_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(stat_option)
	var stat_help := Label.new()
	stat_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stat_help.add_theme_color_override("font_color", Color(0.68, 0.75, 0.78))
	column.add_child(stat_help)

	_add_label(column, "How should it change?")
	var operation_option := OptionButton.new()
	operation_option.add_item("Add (+)", 0)
	operation_option.add_item("Multiply (×)", 1)
	operation_option.add_item("Set (=)", 2)
	operation_option.select(1)
	column.add_child(operation_option)

	_add_label(column, "Value")
	var value_spin := SpinBox.new()
	value_spin.min_value = -1000000.0
	value_spin.max_value = 1000000.0
	value_spin.step = 0.01
	value_spin.value = 1.15
	value_spin.allow_greater = true
	value_spin.allow_lesser = true
	column.add_child(value_spin)

	var row: Dictionary = {
		"panel": panel,
		"heading": label,
		"category": category_option,
		"stat": stat_option,
		"stat_help": stat_help,
		"operation": operation_option,
		"value": value_spin,
		"remove": remove_button
	}
	effect_rows.append(row)
	category_option.item_selected.connect(_on_category_changed.bind(panel))
	stat_option.item_selected.connect(_on_stat_changed.bind(panel))
	remove_button.pressed.connect(_remove_effect_row.bind(panel))
	_refresh_stat_dropdowns()
	_update_remove_buttons()


func _remove_effect_row(panel: Control) -> void:
	if effect_rows.size() <= 1:
		return
	for index in range(effect_rows.size()):
		if effect_rows[index]["panel"] == panel:
			effect_rows.remove_at(index)
			panel.queue_free()
			break
	for index in range(effect_rows.size()):
		(effect_rows[index]["heading"] as Label).text = "Effect " + str(index + 1)
	_update_remove_buttons()


func _update_remove_buttons() -> void:
	for row in effect_rows:
		(row["remove"] as Button).disabled = effect_rows.size() <= 1


func _selected_required_tags() -> Array[String]:
	var tags: Array[String] = []
	if melee_check.button_pressed:
		tags.append("melee")
	if ranged_check.button_pressed:
		tags.append("ranged")
	if physical_check.button_pressed:
		tags.append("physical")
	if magical_check.button_pressed:
		tags.append("magical")
	return tags


func _on_refresh_stats() -> void:
	_discover_player_stats()
	_refresh_stat_dropdowns()
	_set_status("Player attributes refreshed from character scenes.", false)


func _discover_player_stats() -> void:
	discovered_classes.clear()
	var classes: Array[Dictionary] = []

	# Read scene constants and class tags directly from CharacterManager where possible.
	# This lets newly added classes participate without changing the creator.
	var manager_path := String(ProjectSettings.get_setting(CHARACTER_MANAGER_AUTOLOAD, ""))
	if manager_path.begins_with("*"):
		manager_path = manager_path.substr(1)
	if not manager_path.is_empty():
		var manager_script := load(manager_path) as Script
		if manager_script != null:
			var constants := manager_script.get_script_constant_map()
			var enum_map: Dictionary = constants.get("CharacterClass", {})
			var class_tags: Dictionary = constants.get("CLASS_TAGS", {})
			for key in constants.keys():
				var constant_name := String(key)
				if not constant_name.ends_with("_SCENE"):
					continue
				var packed_scene := constants[key] as PackedScene
				if packed_scene == null:
					continue
				var detected_class_id := constant_name.trim_suffix("_SCENE").to_lower()
				var tags: Array[String] = []
				var enum_name := detected_class_id.to_upper()
				if enum_map.has(enum_name):
					for tag in class_tags.get(enum_map[enum_name], []):
						tags.append(String(tag).to_lower())
				classes.append({"name": detected_class_id, "scene": packed_scene, "tags": tags})

	if classes.is_empty():
		for entry in FALLBACK_CLASSES:
			var scene := load(String(entry["path"])) as PackedScene
			if scene == null:
				continue
			var tags: Array[String] = []
			for tag in entry["tags"]:
				tags.append(String(tag))
			classes.append({"name": entry["name"], "scene": scene, "tags": tags})

	for entry in classes:
		var packed_scene: PackedScene = entry["scene"]
		var player_root := packed_scene.instantiate()
		if player_root == null:
			continue

		# Script.get_script_property_list() identifies actual script attributes.
		# Node.get_property_list() with PROPERTY_USAGE_SCRIPT_VARIABLE filtered
		# out legitimate non-@tool player variables in some Godot versions.
		var stats: Array[String] = []
		var character_node: Node = player_root
		if character_node.get_script() == null:
			character_node = _find_scripted_character(player_root)
		if character_node != null:
			var character_script := character_node.get_script() as Script
			while character_script != null:
				for property_info in character_script.get_script_property_list():
					var property_name := String(property_info.get("name", ""))
					var property_type := int(property_info.get("type", TYPE_NIL))
					if property_type not in [TYPE_INT, TYPE_FLOAT]:
						continue
					if property_name.is_empty() or property_name.begins_with("_"):
						continue
					if not stats.has(property_name):
						stats.append(property_name)
				character_script = character_script.get_base_script()
		stats.sort()
		discovered_classes.append({"name": entry["name"], "tags": entry["tags"], "stats": stats})
		player_root.free()


func _find_scripted_character(root: Node) -> Node:
	# Some player scenes wrap the actual CharacterBody3D in a parent node.
	for child in root.get_children():
		if child is CharacterBody3D and child.get_script() != null:
			return child
		var nested := _find_scripted_character(child)
		if nested != null:
			return nested
	return null


func _matching_classes() -> Array[Dictionary]:
	var matching: Array[Dictionary] = []
	var required_tags := _selected_required_tags()
	for entry in discovered_classes:
		var class_tags: Array = entry["tags"]
		var qualifies := true
		for tag in required_tags:
			if not class_tags.has(tag):
				qualifies = false
				break
		if qualifies:
			matching.append(entry)
	return matching


func _available_stats() -> Array[String]:
	var matching := _matching_classes()
	var stats: Array[String] = []
	if matching.is_empty():
		return stats
	# A stat must exist on EVERY class that could receive this upgrade.
	for candidate in matching[0]["stats"]:
		var supported_by_all := true
		for class_entry in matching:
			var class_stats: Array = class_entry["stats"]
			if not class_stats.has(candidate):
				supported_by_all = false
				break
		if supported_by_all:
			stats.append(String(candidate))
	stats.sort()
	return stats


func _approved_stats() -> Array[String]:
	var approved: Array[String] = []
	for stat_name in _available_stats():
		if ATTRIBUTE_CATALOG.has(stat_name):
			approved.append(stat_name)
	return approved


func _on_category_changed(_selected_index: int, panel: Control) -> void:
	_refresh_stat_dropdowns()


func _on_stat_changed(_selected_index: int, panel: Control) -> void:
	for row in effect_rows:
		if row["panel"] == panel:
			_update_stat_help(row)
			return


func _update_stat_help(row: Dictionary) -> void:
	var option: OptionButton = row["stat"]
	var help_label: Label = row["stat_help"]
	if option.selected < 0:
		help_label.text = "No available attributes in this category for the selected classes."
		return
	var stat_name := String(option.get_item_metadata(option.selected))
	help_label.text = String(ATTRIBUTE_CATALOG[stat_name].get("help", ""))


func _refresh_stat_dropdowns() -> void:
	if stat_info_label == null:
		return
	var matching := _matching_classes()
	var approved := _approved_stats()
	if matching.is_empty():
		stat_info_label.text = "No class matches these tags. Change the checkboxes."
	else:
		var names: Array[String] = []
		for entry in matching:
			names.append(String(entry["name"]).capitalize())
		stat_info_label.text = str(approved.size()) + " upgradeable attributes for: " + ", ".join(names)
		if approved.is_empty():
			stat_info_label.text += " (No approved attributes found. Check class tags and Refresh Stats.)"

	for row in effect_rows:
		var option: OptionButton = row["stat"]
		var category_option: OptionButton = row["category"]
		var old_stat := ""
		if option.selected >= 0:
			old_stat = String(option.get_item_metadata(option.selected))
		var selected_category := category_option.get_item_text(category_option.selected)
		option.clear()
		for stat_name in approved:
			var entry: Dictionary = ATTRIBUTE_CATALOG[stat_name]
			if String(entry["category"]) != selected_category:
				continue
			option.add_item(String(entry["label"]))
			option.set_item_metadata(option.item_count - 1, stat_name)
			option.set_item_tooltip(option.item_count - 1, stat_name + " — " + String(entry["help"]))
		if option.item_count > 0:
			var selection := 0
			for index in range(option.item_count):
				if String(option.get_item_metadata(index)) == old_stat:
					selection = index
					break
			option.select(selection)
		_update_stat_help(row)

func _on_icon_dropped(texture: Texture2D) -> void:
	icon_texture = texture
	icon_preview.texture = texture
	icon_hint.text = "Icon selected"


func _validated_effect_specs() -> Array[Dictionary]:
	var upgrade_name := name_edit.text.strip_edges()
	if upgrade_name.is_empty():
		_set_status("Enter an upgrade name.", true)
		return []
	if description_edit.text.strip_edges().is_empty():
		_set_status("Enter an upgrade description.", true)
		return []

	var matching := _matching_classes()
	if matching.is_empty():
		_set_status("No character class matches those tags. Change the tag checkboxes.", true)
		return []
	var allowed_stats := _approved_stats()
	if allowed_stats.is_empty():
		_set_status("No shared player stats found. Click Refresh Stats or check the character scenes.", true)
		return []
	if effect_rows.is_empty():
		_set_status("Add at least one effect.", true)
		return []

	var effect_specs: Array[Dictionary] = []
	var modified_stats: Array[String] = []
	for index in range(effect_rows.size()):
		var row := effect_rows[index]
		var stat_option: OptionButton = row["stat"]
		if stat_option.selected < 0:
			_set_status("Choose a player attribute for effect " + str(index + 1) + ".", true)
			return []
		var stat_name := String(stat_option.get_item_metadata(stat_option.selected))
		if not allowed_stats.has(stat_name):
			_set_status("The attribute '" + stat_name + "' isn't available for these classes.", true)
			return []
		if modified_stats.has(stat_name):
			_set_status("'" + stat_name + "' is used twice. Combine it into one effect for now.", true)
			return []
		modified_stats.append(stat_name)
		var operation: OptionButton = row["operation"]
		var value: SpinBox = row["value"]
		effect_specs.append({
			"stat_name": stat_name,
			"operation": operation.get_selected_id(),
			"value": value.value
		})

	return effect_specs


func _create_upgrade() -> void:
	if not loaded_upgrade_path.is_empty():
		_set_status("An existing upgrade is loaded. Click New Upgrade before creating a separate one.", true)
		return
	var upgrade_name := name_edit.text.strip_edges()
	var effect_specs := _validated_effect_specs()
	if effect_specs.is_empty():
		return

	var upgrade_script := load("res://Upgrades/UpgradeData.gd") as Script
	var effect_script := load("res://Upgrades/UpgradeEffect.gd") as Script
	if upgrade_script == null or effect_script == null:
		_set_status("UpgradeData.gd or UpgradeEffect.gd is missing.", true)
		return

	var file_base := upgrade_name.to_snake_case()
	var safe_name := ""
	for character in file_base:
		if character in "abcdefghijklmnopqrstuvwxyz0123456789_":
			safe_name += character
	if safe_name.is_empty():
		_set_status("Name needs at least one Latin letter or number.", true)
		return

	var absolute_dir := ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if dir_error != OK:
		_set_status("Could not create Upgrades/Data folder.", true)
		return
	var save_path := OUTPUT_DIRECTORY.path_join(safe_name + ".tres")
	if ResourceLoader.exists(save_path) or FileAccess.file_exists(save_path):
		_set_status("An upgrade named '" + safe_name + "' already exists. Nothing overwritten.", true)
		return

	var upgrade: Resource = upgrade_script.new()
	upgrade.set("upgrade_name", upgrade_name)
	upgrade.set("description", description_edit.text)
	upgrade.set("icon", icon_texture)
	upgrade.set("required_tags", _selected_required_tags())
	upgrade.set("max_stacks", int(max_stacks_spin.value))

	# Append to the typed Array[UpgradeEffect] already created by UpgradeData.
	var typed_effects: Array = upgrade.get("effects")
	for spec in effect_specs:
		var effect: Resource = effect_script.new()
		effect.set("stat_name", spec["stat_name"])
		effect.set("operation", spec["operation"])
		effect.set("value", spec["value"])
		typed_effects.append(effect)
	upgrade.set("effects", typed_effects)

	var save_error := ResourceSaver.save(upgrade, save_path)
	if save_error != OK:
		_set_status("Could not save upgrade (error " + str(save_error) + ").", true)
		return

	EditorInterface.get_resource_filesystem().scan()
	_set_status("Created: " + save_path + " (" + str(effect_specs.size()) + " effects)", false)
	_refresh_existing_upgrades()
	_reset_for_new_upgrade(false)


func _refresh_existing_upgrades() -> void:
	var previous_path := ""
	if existing_option.selected >= 0:
		previous_path = String(existing_option.get_item_metadata(existing_option.selected))
	existing_option.clear()
	existing_option.add_item("Choose an upgrade to edit...")
	existing_option.set_item_metadata(0, "")
	var files := DirAccess.get_files_at(OUTPUT_DIRECTORY)
	files.sort()
	for filename in files:
		if not filename.ends_with(".tres"):
			continue
		var path := OUTPUT_DIRECTORY.path_join(filename)
		var data := ResourceLoader.load(path)
		if data == null or not _is_upgrade_resource(data):
			continue
		var display_name := String(data.get("upgrade_name"))
		if display_name.is_empty():
			display_name = filename.get_basename()
		existing_option.add_item(display_name + " (" + filename + ")")
		existing_option.set_item_metadata(existing_option.item_count - 1, path)
		if path == previous_path:
			existing_option.select(existing_option.item_count - 1)
	if existing_option.selected < 0:
		existing_option.select(0)


func _is_upgrade_resource(data: Resource) -> bool:
	var data_script := data.get_script() as Script
	return data_script != null and data_script.resource_path == "res://Upgrades/UpgradeData.gd"


func _load_selected_upgrade() -> void:
	if existing_option.selected <= 0:
		_set_status("Choose an existing upgrade from the dropdown first.", true)
		return
	var path := String(existing_option.get_item_metadata(existing_option.selected))
	var data := ResourceLoader.load(path)
	if data == null or not _is_upgrade_resource(data):
		_set_status("Unable to open the selected UpgradeData resource.", true)
		return
	var tags: Array = data.get("required_tags")
	for tag in tags:
		if not ["melee", "ranged", "physical", "magical"].has(String(tag)):
			_set_status("Cannot edit: unknown tag '" + String(tag) + "'. No changes made.", true)
			return
	var effects: Array = data.get("effects")
	if effects.is_empty():
		_set_status("Cannot edit: this upgrade has no effects. No changes made.", true)
		return
	# Refuse unsupported effects rather than silently replacing them with the first dropdown item.
	for effect in effects:
		if effect == null:
			_set_status("Cannot edit: a missing effect was found. No changes made.", true)
			return
		var stat_name := String(effect.get("stat_name"))
		if not ATTRIBUTE_CATALOG.has(stat_name):
			_set_status("Cannot edit: attribute '" + stat_name + "' is not in the approved catalog. No changes made.", true)
			return

	name_edit.text = String(data.get("upgrade_name"))
	description_edit.text = String(data.get("description"))
	icon_texture = data.get("icon") as Texture2D
	icon_preview.texture = icon_texture
	icon_hint.text = "Icon selected" if icon_texture != null else "Drop PNG / WEBP / JPG here"
	melee_check.button_pressed = tags.has("melee")
	ranged_check.button_pressed = tags.has("ranged")
	physical_check.button_pressed = tags.has("physical")
	magical_check.button_pressed = tags.has("magical")
	max_stacks_spin.value = int(data.get("max_stacks"))
	_clear_effect_rows()
	for effect in effects:
		_add_effect_row()
		var row: Dictionary = effect_rows.back()
		var stat_name := String(effect.get("stat_name"))
		var category_option: OptionButton = row["category"]
		var category_name := String(ATTRIBUTE_CATALOG[stat_name]["category"])
		for i in range(category_option.item_count):
			if category_option.get_item_text(i) == category_name:
				category_option.select(i)
				break
		_refresh_stat_dropdowns()
		var stat_option: OptionButton = row["stat"]
		var found := false
		for i in range(stat_option.item_count):
			if String(stat_option.get_item_metadata(i)) == stat_name:
				stat_option.select(i)
				found = true
				break
		if not found:
			# Leave editing disabled, rather than corrupting an effect on save.
			_set_status("Attribute '" + stat_name + "' isn't available for these class tags. Fix class tags or Refresh Stats before saving.", true)
			stat_option.select(-1)
		(row["operation"] as OptionButton).select(int(effect.get("operation")))
		(row["value"] as SpinBox).value = float(effect.get("value"))
		_update_stat_help(row)
	loaded_upgrade_path = path
	_update_edit_mode()
	if _validated_effect_specs().size() == effects.size():
		_set_status("Loaded for editing: " + path + ". Nothing has been saved yet.", false)


func _clear_effect_rows() -> void:
	for row in effect_rows:
		(row["panel"] as Control).queue_free()
	effect_rows.clear()


func _reset_for_new_upgrade(show_status: bool = true) -> void:
	loaded_upgrade_path = ""
	name_edit.clear()
	description_edit.clear()
	icon_texture = null
	icon_preview.texture = null
	icon_hint.text = "Drop PNG / WEBP / JPG here"
	for checkbox in [melee_check, ranged_check, physical_check, magical_check]:
		checkbox.button_pressed = false
	max_stacks_spin.value = 1
	_clear_effect_rows()
	_add_effect_row()
	_update_edit_mode()
	if show_status:
		_set_status("New upgrade form ready. Existing resources are unchanged.", false)


func _update_edit_mode() -> void:
	var editing := not loaded_upgrade_path.is_empty()
	loaded_path_label.text = "Editing: " + loaded_upgrade_path if editing else "Mode: Create a new upgrade"
	save_button.disabled = not editing


func _request_save_changes() -> void:
	if loaded_upgrade_path.is_empty():
		_set_status("Load an existing upgrade first.", true)
		return
	if _validated_effect_specs().is_empty():
		return
	if not FileAccess.file_exists(loaded_upgrade_path):
		_set_status("The original upgrade file no longer exists. Nothing saved.", true)
		return
	save_confirmation.dialog_text = "Overwrite this existing upgrade?\n\n" + loaded_upgrade_path + "\n\nThis will update its name, icon, tags, stacks and effects."
	save_confirmation.popup_centered()


func _save_loaded_upgrade() -> void:
	if loaded_upgrade_path.is_empty():
		return
	var effect_specs := _validated_effect_specs()
	if effect_specs.is_empty():
		return
	var data := ResourceLoader.load(loaded_upgrade_path)
	var effect_script := load("res://Upgrades/UpgradeEffect.gd") as Script
	if data == null or not _is_upgrade_resource(data) or effect_script == null:
		_set_status("Could not load original resource or UpgradeEffect.gd. Nothing saved.", true)
		return
	var new_effects: Array = data.get("effects")
	new_effects.clear()
	for spec in effect_specs:
		var effect: Resource = effect_script.new()
		effect.set("stat_name", spec["stat_name"])
		effect.set("operation", spec["operation"])
		effect.set("value", spec["value"])
		new_effects.append(effect)
	data.set("upgrade_name", name_edit.text.strip_edges())
	data.set("description", description_edit.text)
	data.set("icon", icon_texture)
	data.set("required_tags", _selected_required_tags())
	data.set("max_stacks", int(max_stacks_spin.value))
	data.set("effects", new_effects)
	var error := ResourceSaver.save(data, loaded_upgrade_path)
	if error != OK:
		_set_status("Save failed (error " + str(error) + ").", true)
		return
	EditorInterface.get_resource_filesystem().scan()
	_refresh_existing_upgrades()
	_set_status("Saved changes to: " + loaded_upgrade_path, false)


func _set_status(message: String, is_error: bool) -> void:
	status_label.text = message
	status_label.modulate = Color(1.0, 0.5, 0.5) if is_error else Color(0.55, 1.0, 0.65)


class IconDropArea extends PanelContainer:
	signal icon_dropped(texture: Texture2D)

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return _get_texture_path(data) != ""

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		var path := _get_texture_path(data)
		if path.is_empty():
			return
		var texture := load(path) as Texture2D
		if texture != null:
			icon_dropped.emit(texture)

	func _get_texture_path(data: Variant) -> String:
		if not (data is Dictionary):
			return ""
		if data.get("type", "") != "files":
			return ""
		var files: PackedStringArray = data.get("files", PackedStringArray())
		if files.size() != 1:
			return ""
		var path := String(files[0])
		if path.get_extension().to_lower() not in ["png", "jpg", "jpeg", "webp", "svg"]:
			return ""
		return path
