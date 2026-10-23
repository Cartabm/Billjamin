extends Control
## Class-independent upgrade menu. Availability is based on player capabilities.
## Maximum six unique upgrades; existing card textures and icons are preserved.

@export_group("Upgrade Limits")
@export_range(1, 10, 1) var max_unique_upgrades: int = 6

var player: CharacterBody3D
@onready var card_row: HBoxContainer = find_child("CardRow", true, false) as HBoxContainer

var upgrade_hover_tweens: Dictionary = {}
var opening_tween: Tween
var ban_mode: bool = false
var hovered_card: Button = null
var controls_panel: VBoxContainer
var currency_label: Label
var bans_label: Label
var ban_button: Button
var reroll_button: Button
var ban_overlays: Dictionary = {}
var owned_upgrades: Dictionary = {} # Button name -> number of times selected

# New resource-driven upgrades use one reusable scene copied from PowerShotButton.
# Existing buttons continue working exactly as before.
const UPGRADE_DATA_DIRECTORY := "res://Upgrades/Data"
const RESOURCE_CARD_SCENE_PATH := "res://Upgrades/UpgradeCardStyled.tscn"
var resource_upgrades: Dictionary = {} # Button name -> UpgradeData
var resource_buttons: Array[Button] = []

const BUTTON_NAMES: Array[String] = [
	"PowerShotButton",
	"RapidFireButton",
	"SwiftFeetButton",
	"SwarmcallerButton",
	"ExperienceBoostButton",
	"MultishotButton",
	"MaxHealthButton",
	"ToughSkinButton",
	"CriticalStrikeButton",
	"RicochetButton",
	"IncreasedRangeButton",
	"BladeFlurryButton"
]


# Tags restrict an upgrade to matching character combat types.
# An empty list means the upgrade is available to all combat types.
# Multiple tags are ALL required (e.g. ranged + physical).
#
# Existing characters work immediately through CharacterManager.
# For a future character, add its name to CHARACTER_TAGS, or set
# "upgrade_tags" metadata on the player's root node in the Inspector.
const CHARACTER_TAGS := {
	"archer": ["ranged", "physical"],
	"rogue": ["melee", "physical"]
}

# Default tags for existing upgrade cards.
# These can be overridden by "upgrade_tags" metadata on an individual button.
const UPGRADE_TAGS := {
	"PowerShotButton": ["ranged", "physical"],
	"RapidFireButton": ["ranged"],
	"SwiftFeetButton": [],
	"SwarmcallerButton": [],
	"ExperienceBoostButton": [],
	"MultishotButton": ["ranged"],
	"MaxHealthButton": [],
	"ToughSkinButton": [],
	"CriticalStrikeButton": [],
	"RicochetButton": ["ranged"],
	"IncreasedRangeButton": [],
	"BladeFlurryButton": []
}


func _player_upgrade_tags() -> Array[String]:
	return CharacterManager.get_selected_class_tags()


func _upgrade_matches_player(button: Button) -> bool:
	if button == null:
		return false

	# Per-card metadata takes priority over the default table.
	var required_tags: Variant = button.get_meta(
		"upgrade_tags",
		UPGRADE_TAGS.get(String(button.name), [])
	)
	var player_tags := _player_upgrade_tags()
	for tag in required_tags:
		if not player_tags.has(String(tag).strip_edges().to_lower()):
			return false
	return true


func _find_player() -> CharacterBody3D:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return null

	for node_name in ["Player", "TestPlayer"]:
		var candidate := scene_root.find_child(node_name, true, false)
		if candidate is CharacterBody3D:
			return candidate as CharacterBody3D

	# Future classes can join the "player" group without a specific node name.
	for candidate in get_tree().get_nodes_in_group("player"):
		if candidate is CharacterBody3D and scene_root.is_ancestor_of(candidate):
			return candidate as CharacterBody3D

	return null


func _refresh_player() -> void:
	player = _find_player()


func _has_property(object: Object, property_name: String) -> bool:
	if object == null or not is_instance_valid(object):
		return false
	for property_info in object.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			return true
	return false


func _can_apply_upgrade(button_name: String) -> bool:
	if player == null or not is_instance_valid(player):
		return false

	if resource_upgrades.has(button_name):
		return _can_apply_resource_upgrade(resource_upgrades[button_name])

	match button_name:
		"PowerShotButton":
			return _has_property(player, "projectile_damage")
		"RapidFireButton":
			return _has_property(player, "attack_interval") or _has_property(player, "fire_rate")
		"SwiftFeetButton":
			return _has_property(player, "move_speed")
		"SwarmcallerButton":
			var spawner := get_tree().current_scene.get_node_or_null("EnemySpawner")
			return spawner != null and _has_property(spawner, "current_horde_size") and _has_property(spawner, "spawn_interval") and _has_property(spawner, "minimum_spawn_interval")
		"ExperienceBoostButton":
			return _has_property(player, "xp_multiplier") and float(player.get("xp_multiplier")) < 10.0
		"MultishotButton":
			return _has_property(player, "multishot_count")
		"MaxHealthButton":
			return _has_property(player, "max_health") and _has_property(player, "current_health")
		"ToughSkinButton":
			return _has_property(player, "tough_skin_stacks") and _has_property(player, "damage_reduction") and _has_property(player, "TOUGH_SKIN_REDUCTION") and _has_property(player, "TOUGH_SKIN_MAX_STACKS") and int(player.get("tough_skin_stacks")) < int(player.get("TOUGH_SKIN_MAX_STACKS"))
		"CriticalStrikeButton":
			return player.has_method("upgrade_critical_strike") and _has_property(player, "critical_hit_chance") and float(player.get("critical_hit_chance")) < 1.0
		"RicochetButton":
			return _has_property(player, "ricochet_stacks") and int(player.get("ricochet_stacks")) < 3
		"IncreasedRangeButton":
			return player.has_method("increased_attack_range")
		"BladeFlurryButton":
			return _has_property(player, "blade_flurry_level") and int(player.get("blade_flurry_level")) < 20
	return false


func _load_resource_upgrade_cards() -> void:
	if card_row == null:
		return
	if not ResourceLoader.exists(RESOURCE_CARD_SCENE_PATH):
		push_warning("UpgradeMenu: Styled card template not found at " + RESOURCE_CARD_SCENE_PATH)
		return
	var directory := DirAccess.open(UPGRADE_DATA_DIRECTORY)
	if directory == null:
		push_warning("UpgradeMenu: Upgrade data folder not found: " + UPGRADE_DATA_DIRECTORY)
		return

	var card_scene := load(RESOURCE_CARD_SCENE_PATH) as PackedScene
	if card_scene == null:
		push_warning("UpgradeMenu: Styled card template is not a PackedScene.")
		return

	for file_name in directory.get_files():
		var resource_name := String(file_name)
		if resource_name.ends_with(".remap"):
			resource_name = resource_name.trim_suffix(".remap")
		if not resource_name.ends_with(".tres"):
			continue
		var path := UPGRADE_DATA_DIRECTORY.path_join(resource_name)
		var data := load(path) as UpgradeData
		if data == null:
			continue
		var button_name := "Resource_" + resource_name.get_basename()
		if resource_upgrades.has(button_name):
			continue
		var button := card_scene.instantiate() as Button
		if button == null:
			push_error("UpgradeMenu: Styled card scene root must be a Button.")
			return
		button.name = button_name
		card_row.add_child(button)
		if button.has_method("set_upgrade"):
			button.call("set_upgrade", data)
		else:
			push_error("UpgradeMenu: Styled card is missing UpgradeCard.gd script.")
			button.queue_free()
			continue
		button.set_meta("upgrade_tags", data.required_tags)
		resource_upgrades[button_name] = data
		resource_buttons.append(button)


func _can_apply_resource_upgrade(data: UpgradeData) -> bool:
	if data == null or data.effects.is_empty():
		return false
	for effect in data.effects:
		if effect == null or effect.stat_name.strip_edges().is_empty():
			return false
		if not _has_property(player, effect.stat_name.strip_edges()):
			return false
		var value: Variant = player.get(effect.stat_name.strip_edges())
		if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
			return false
	return true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_refresh_player()
	_load_resource_upgrade_cards()
	if player == null:
		push_warning("UpgradeMenu: Player not found yet; will search when the menu opens.")
	if card_row == null:
		push_error("UpgradeMenu: CardRow node not found.")

	for button_name in BUTTON_NAMES:
		if find_child(button_name, true, false) == null:
			push_warning("UpgradeMenu: missing button " + button_name)

	for button in _all_buttons():
		var button_name := String(button.name)
		var normal_style: StyleBox = button.get_theme_stylebox("normal")
		if normal_style != null:
			button.add_theme_stylebox_override("hover", normal_style)
			button.add_theme_stylebox_override("pressed", normal_style)
			button.add_theme_stylebox_override("hover_pressed", normal_style)

		if not button.pressed.is_connected(_apply_upgrade.bind(button_name)):
			button.pressed.connect(_apply_upgrade.bind(button_name))
		if not button.mouse_entered.is_connected(_on_upgrade_button_mouse_entered.bind(button)):
			button.mouse_entered.connect(_on_upgrade_button_mouse_entered.bind(button))
		if not button.mouse_exited.is_connected(_on_upgrade_button_mouse_exited.bind(button)):
			button.mouse_exited.connect(_on_upgrade_button_mouse_exited.bind(button))

	_build_run_controls()
	RunUpgradeState.state_changed.connect(_refresh_run_controls)
	_hide_all_card_controls()
	hide()


func _hide_all_card_controls() -> void:
	if card_row == null:
		return
	for child in card_row.get_children():
		if child is Control:
			child.hide()


func _all_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for button_name in BUTTON_NAMES:
		var button := find_child(button_name, true, false) as Button
		if button != null:
			buttons.append(button)
	for button in resource_buttons:
		if is_instance_valid(button):
			buttons.append(button)
	return buttons


func _is_upgrade_available(button: Button) -> bool:
	if button == null or not _upgrade_matches_player(button):
		return false
	if not _can_apply_upgrade(String(button.name)):
		return false
	if resource_upgrades.has(String(button.name)):
		var data: UpgradeData = resource_upgrades[String(button.name)]
		if int(owned_upgrades.get(String(button.name), 0)) >= maxi(1, data.max_stacks):
			return false
	if String(button.name) == "BladeFlurryButton" and int(owned_upgrades.get("BladeFlurryButton", 0)) >= 20:
		return false
	if RunUpgradeState.banned_upgrades.has(String(button.name)):
		return false
	if not owned_upgrades.has(button.name) and owned_upgrades.size() >= max_unique_upgrades:
		return false
	return true


func randomize_upgrade_choices() -> Array[Button]:

	_hide_all_card_controls()
	var available: Array[Button] = []
	for button in _all_buttons():
		button.hide()
		button.scale = Vector2.ONE
		button.self_modulate = Color.WHITE
		button.modulate.a = 1.0
		_set_ban_overlay(button, false)
		if _is_upgrade_available(button):
			available.append(button)
	available.shuffle()
	var selected: Array[Button] = []
	for i in range(mini(3, available.size())):
		selected.append(available[i])
		available[i].show()
	if selected.is_empty():
		push_warning("UpgradeMenu: No eligible upgrades remain.")
	return selected


func show_upgrade_menu() -> void:
	if player == null or not is_instance_valid(player):
		_refresh_player()
	if player == null:
		return
	var sound := player.get_node_or_null("LevelUpSound") as AudioStreamPlayer
	if sound != null:
		sound.process_mode = Node.PROCESS_MODE_ALWAYS
		sound.stop()
		sound.play()
	ban_mode = false
	_refresh_run_controls()
	show()
	var selected := randomize_upgrade_choices()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	await get_tree().process_frame
	if not is_inside_tree() or not visible or card_row == null:
		return
	if opening_tween and opening_tween.is_valid():
		opening_tween.kill()
	var center := card_row.size.x * 0.5
	opening_tween = create_tween().set_parallel(true)
	opening_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for button in selected:
		var final_position := button.position
		button.position.x = center - button.size.x * 0.5
		button.pivot_offset = button.size * 0.5
		button.modulate.a = 0.0
		opening_tween.tween_property(button, "position", final_position, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		opening_tween.tween_property(button, "modulate:a", 1.0, 0.35)


func close_upgrade_menu() -> void:
	ban_mode = false
	_clear_ban_overlays()
	if opening_tween and opening_tween.is_valid():
		opening_tween.kill()
	for button in _all_buttons():
		button.scale = Vector2.ONE
		button.self_modulate = Color.WHITE
		button.modulate.a = 1.0
	hide()
	get_tree().paused = false


func _apply_upgrade(button_name: String) -> void:
	if player == null or not is_instance_valid(player):
		_refresh_player()
	if player == null:
		return
	var button := find_child(button_name, true, false) as Button
	if button == null or not _is_upgrade_available(button):
		return
	if ban_mode:
		_ban_card(button)
		return

	# New data-driven cards apply all effects without an additional match case.
	if resource_upgrades.has(button_name):
		var data: UpgradeData = resource_upgrades[button_name]
		if not UpgradeApplier.apply_upgrade(data, player):
			push_warning("UpgradeMenu: Failed to apply " + data.upgrade_name)
			return
		if player.has_method("refresh_health"):
			player.call("refresh_health", false)
		owned_upgrades[button_name] = int(owned_upgrades.get(button_name, 0)) + 1
		close_upgrade_menu()
		return

	match button_name:
		"PowerShotButton":
			player.set(
				"ranged_projectile_damage_bonus",
				int(player.get("ranged_projectile_damage_bonus")) +2
			)
			if _has_property(player, "attack_interval"):
				player.set("attack_interval", player.get("attack_interval") * 0.85)
			else:
				player.set("fire_rate", player.get("fire_rate") * 0.85)
		"SwiftFeetButton":
			player.set("move_speed", player.get("move_speed") * 1.15)
		"SwarmcallerButton":
			var spawner := get_tree().current_scene.get_node_or_null("EnemySpawner")
			if spawner == null:
				return
			spawner.set("current_horde_size", spawner.get("current_horde_size") + 2)
			spawner.set("spawn_interval", maxf(float(spawner.get("minimum_spawn_interval")), float(spawner.get("spawn_interval")) * 0.85))
		"ExperienceBoostButton":
			player.set("xp_multiplier", minf(float(player.get("xp_multiplier")) * 1.2, 10.0))
		"MultishotButton":
			player.set("multishot_count", player.get("multishot_count") + 1)
		"MaxHealthButton":
			player.set("max_health", player.get("max_health") + 25)
			player.set("current_health", player.get("current_health") + 25)
			if player.has_method("_update_hud"):
				player.call("_update_hud", false, false)
			elif _has_property(player, "player_health_bar") and player.get("player_health_bar") != null:
				var health_bar: Object = player.get("player_health_bar")
				if health_bar.has_method("animate_health"):
					health_bar.call("animate_health", float(player.get("current_health")) / float(maxi(int(player.get("max_health")), 1)))
				if health_bar.has_method("set_health_values"):
					health_bar.call("set_health_values", player.get("current_health"), player.get("max_health"))
		"ToughSkinButton":
			player.set("tough_skin_stacks", player.get("tough_skin_stacks") + 1)
			player.set("damage_reduction", player.get("tough_skin_stacks") * player.get("TOUGH_SKIN_REDUCTION"))
		"CriticalStrikeButton":
			player.call("upgrade_critical_strike")
		"IncreasedRangeButton":
			player.call("increased_attack_range")
		"BladeFlurryButton":
			player.set("blade_flurry_level", mini(int(player.get("blade_flurry_level")) + 1, 20))
		"RicochetButton":
			player.set("ricochet_stacks", mini(int(player.get("ricochet_stacks")) + 1, 3))
		_:
			return

	owned_upgrades[button_name] = int(owned_upgrades.get(button_name, 0)) + 1
	close_upgrade_menu()


func _on_upgrade_button_mouse_entered(button: Button) -> void:
	if upgrade_hover_tweens.has(button):
		var old: Tween = upgrade_hover_tweens[button]
		if old.is_valid():
			old.kill()
	button.pivot_offset = button.size * 0.5
	if ban_mode:
		hovered_card = button
		_set_ban_overlay(button, true)
	var tween := create_tween().set_parallel(true)
	upgrade_hover_tweens[button] = tween
	tween.tween_property(button, "scale", Vector2(1.06, 1.06), 0.12)
	tween.tween_property(button, "self_modulate", Color(1.25, 1.25, 1.25), 0.12)


func _on_upgrade_button_mouse_exited(button: Button) -> void:
	if upgrade_hover_tweens.has(button):
		var old: Tween = upgrade_hover_tweens[button]
		if old.is_valid():
			old.kill()
	if hovered_card == button:
		hovered_card = null
	_set_ban_overlay(button, false)
	var tween := create_tween().set_parallel(true)
	upgrade_hover_tweens[button] = tween
	tween.tween_property(button, "scale", Vector2.ONE, 0.12)
	tween.tween_property(button, "self_modulate", Color.WHITE, 0.12)


func style_upgrade_card(button: Button, title: String, description: String) -> void:
	if not is_instance_valid(button):
		return
	button.text = ""
	var rich_text := button.get_node_or_null("UpgradeText") as RichTextLabel
	if rich_text == null:
		rich_text = RichTextLabel.new()
		rich_text.name = "UpgradeText"
		button.add_child(rich_text)
	rich_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rich_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rich_text.bbcode_enabled = true
	rich_text.fit_content = false
	rich_text.scroll_active = false
	rich_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rich_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rich_text.text = "[center][font_size=28][b]" + title + "[/b][/font_size]\n[font_size=20]" + description + "[/font_size][/center]"


# UI is created in code to avoid changing the existing card scene or textures.
func _build_run_controls() -> void:
	if card_row == null:
		return
	controls_panel = VBoxContainer.new()
	controls_panel.name = "UpgradeRunControls"
	controls_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	controls_panel.add_theme_constant_override("separation", 8)
	# Place a floating banner directly below the cards without changing their parent layout.
	add_child(controls_panel)
	controls_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	controls_panel.z_index = 10
	var status_row := HBoxContainer.new()
	status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	status_row.add_theme_constant_override("separation", 32)
	controls_panel.add_child(status_row)
	currency_label = Label.new()
	currency_label.name = "CurrencyLabel"
	status_row.add_child(currency_label)
	bans_label = Label.new()
	bans_label.name = "BanCountLabel"
	status_row.add_child(bans_label)
	var action_row := HBoxContainer.new()
	action_row.name = "ActionRow"
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 16)
	controls_panel.add_child(action_row)
	ban_button = Button.new()
	ban_button.name = "BanButton"
	ban_button.custom_minimum_size = Vector2(175, 42)
	ban_button.pressed.connect(_toggle_ban_mode)
	action_row.add_child(ban_button)
	reroll_button = Button.new()
	reroll_button.name = "RerollButton"
	reroll_button.custom_minimum_size = Vector2(175, 42)
	reroll_button.pressed.connect(_reroll_cards)
	action_row.add_child(reroll_button)
	_refresh_run_controls()


func _process(_delta: float) -> void:
	if not visible or controls_panel == null or card_row == null:
		return
	# Position relative to the actual CardRow, including when the window resizes.
	var card_bottom := card_row.get_global_rect().end
	var card_top := card_row.get_global_rect().position
	controls_panel.global_position = Vector2(card_top.x + (card_row.size.x - controls_panel.size.x) * 0.5, card_bottom.y + 12.0)


func _refresh_run_controls() -> void:
	if currency_label == null:
		return
	currency_label.text = "Currency: %d" % RunUpgradeState.currency
	bans_label.text = "Bans: %d / %d" % [RunUpgradeState.bans_remaining(), RunUpgradeState.max_bans]
	ban_button.text = "CANCEL BAN" if ban_mode else "BAN"
	ban_button.disabled = not ban_mode and RunUpgradeState.bans_remaining() <= 0
	reroll_button.text = "REROLL — %d" % RunUpgradeState.reroll_cost()
	reroll_button.disabled = RunUpgradeState.currency < RunUpgradeState.reroll_cost()


func _toggle_ban_mode() -> void:
	if not ban_mode and RunUpgradeState.bans_remaining() <= 0:
		return
	ban_mode = not ban_mode
	_clear_ban_overlays()
	_refresh_run_controls()
	if ban_mode:
		for button in _all_buttons():
			if button.visible and button.get_global_rect().has_point(get_global_mouse_position()):
				hovered_card = button
				_set_ban_overlay(button, true)
				break


func _set_ban_overlay(button: Button, enabled: bool) -> void:
	if not is_instance_valid(button):
		return
	var overlay: Label = ban_overlays.get(button)
	if overlay == null or not is_instance_valid(overlay):
		overlay = Label.new()
		overlay.name = "BanXOverlay"
		overlay.text = "✕"
		overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.add_theme_font_size_override("font_size", 110)
		overlay.add_theme_color_override("font_color", Color(1.0, 0.1, 0.1, 0.95))
		overlay.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 1.0))
		overlay.add_theme_constant_override("shadow_offset_x", 3)
		overlay.add_theme_constant_override("shadow_offset_y", 3)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(overlay)
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ban_overlays[button] = overlay
	overlay.visible = enabled and ban_mode


func _clear_ban_overlays() -> void:
	hovered_card = null
	for button in ban_overlays.keys():
		if is_instance_valid(button):
			_set_ban_overlay(button, false)


func _ban_card(button: Button) -> void:
	if not RunUpgradeState.ban_upgrade(String(button.name)):
		return
	ban_mode = false
	_clear_ban_overlays()
	# Replace only the banned card, leaving the other two unchanged.
	button.hide()
	var available: Array[Button] = []
	for candidate in _all_buttons():
		if not candidate.visible and _is_upgrade_available(candidate):
			available.append(candidate)
	available.shuffle()
	if not available.is_empty():
		var replacement := available[0]
		replacement.show()
		replacement.scale = Vector2.ONE
		replacement.modulate.a = 1.0
	_refresh_run_controls()


func _reroll_cards() -> void:
	if not RunUpgradeState.buy_reroll():
		return
	ban_mode = false
	_clear_ban_overlays()
	randomize_upgrade_choices()
	_refresh_run_controls()
