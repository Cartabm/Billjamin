extends Control
## Attach to the existing UpgradeMenu node (not the CardRow).
## Player retains the gameplay stats; this script owns card selection and UI.

@onready var player = get_tree().current_scene.find_child("Player", true, false)
@onready var card_row: HBoxContainer = find_child("CardRow", true, false) as HBoxContainer

var upgrade_hover_tweens: Dictionary = {}
var opening_tween: Tween

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
	"RicochetButton"
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if player == null:
		push_error("UpgradeMenu: Player node not found.")

	if card_row == null:
		push_error("UpgradeMenu: CardRow node not found.")

	for name in BUTTON_NAMES:
		var button := find_child(name, true, false) as Button

		if button == null:
			push_warning("UpgradeMenu: missing button " + name)
			continue

		# Force all button states to use the Normal background.
		var normal_style: StyleBox = button.get_theme_stylebox("normal")
		button.add_theme_stylebox_override("hover", normal_style)
		button.add_theme_stylebox_override("pressed", normal_style)
		button.add_theme_stylebox_override("hover_pressed", normal_style)

		# Connect upgrade button interactions.
		button.pressed.connect(_apply_upgrade.bind(name))
		button.mouse_entered.connect(_on_upgrade_button_mouse_entered.bind(button))
		button.mouse_exited.connect(_on_upgrade_button_mouse_exited.bind(button))

		# Prevent the ability icon from blocking mouse input.
		var icon := button.get_node_or_null("AbilityIcon") as Control
		if icon:
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Hide all card controls, including any not yet registered in BUTTON_NAMES.
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
	for name in BUTTON_NAMES:
		var button := find_child(name, true, false) as Button
		if button:
			buttons.append(button)
	return buttons

func _is_upgrade_available(button: Button) -> bool:
	if player == null:
		return false
	if button.name == "CriticalStrikeButton":
		return player.critical_hit_chance < 1.0
	if button.name == "ToughSkinButton":
		return player.tough_skin_stacks < player.TOUGH_SKIN_MAX_STACKS
	if button.name == "ExperienceBoostButton":
		return player.xp_multiplier < 10.0
	if button.name == "RicochetButton":
		return player.ricochet_stacks < 3
	return true

func randomize_upgrade_choices() -> Array[Button]:
	_hide_all_card_controls()
	var available: Array[Button] = []
	for button in _all_buttons():
		button.hide()
		button.scale = Vector2.ONE
		button.self_modulate = Color.WHITE
		if _is_upgrade_available(button):
			available.append(button)
	available.shuffle()
	var selected: Array[Button] = []
	for i in range(mini(3, available.size())):
		selected.append(available[i])
		selected[i].show()
	if selected.is_empty():
		push_warning("No eligible upgrades remain.")
	return selected

func show_upgrade_menu() -> void:
	if player == null:
		return
	var sound := player.get_node_or_null("LevelUpSound") as AudioStreamPlayer
	if sound:
		sound.process_mode = Node.PROCESS_MODE_ALWAYS
		sound.stop()
		sound.play()
	show()
	var selected := randomize_upgrade_choices()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	# Allow HBoxContainer to arrange the three visible cards before animating.
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
	if opening_tween and opening_tween.is_valid():
		opening_tween.kill()
	for button in _all_buttons():
		button.scale = Vector2.ONE
		button.self_modulate = Color.WHITE
		button.modulate.a = 1.0
	hide()
	get_tree().paused = false

func _apply_upgrade(button_name: String) -> void:
	if player == null:
		return
	match button_name:
		"PowerShotButton":
			player.projectile_damage += 1
		"RapidFireButton":
			player.fire_rate *= 0.85
		"SwiftFeetButton":
			player.move_speed *= 1.15
		"SwarmcallerButton":
			var spawner = get_tree().current_scene.get_node_or_null("EnemySpawner")
			if spawner:
				spawner.current_horde_size += 2
				spawner.spawn_interval = maxf(spawner.minimum_spawn_interval, spawner.spawn_interval * 0.85)
		"ExperienceBoostButton":
			player.xp_multiplier = minf(player.xp_multiplier * 1.2, 10.0)
		"MultishotButton":
			player.multishot_count += 1
		"MaxHealthButton":
			player.max_health += 25
			player.current_health += 25
			if player.player_health_bar:
				player.player_health_bar.animate_health(float(player.current_health) / float(maxi(player.max_health, 1)))
				player.player_health_bar.set_health_values(player.current_health, player.max_health)
		"ToughSkinButton":
			if player.tough_skin_stacks >= player.TOUGH_SKIN_MAX_STACKS:
				return
			player.tough_skin_stacks += 1
			player.damage_reduction = player.tough_skin_stacks * player.TOUGH_SKIN_REDUCTION
		"CriticalStrikeButton":
			player.upgrade_critical_strike()
		"RicochetButton":
			if player.ricochet_stacks >= 3:
				return
			player.ricochet_stacks = mini(player.ricochet_stacks + 1, 3)
		_:
			return
	close_upgrade_menu()

func _on_upgrade_button_mouse_entered(button: Button) -> void:
	if upgrade_hover_tweens.has(button):
		var old: Tween = upgrade_hover_tweens[button]
		if old.is_valid():
			old.kill()
	button.pivot_offset = button.size * 0.5
	var tween := create_tween().set_parallel(true)
	upgrade_hover_tweens[button] = tween
	tween.tween_property(button, "scale", Vector2(1.06, 1.06), 0.12)
	tween.tween_property(button, "self_modulate", Color(1.25, 1.25, 1.25), 0.12)

func _on_upgrade_button_mouse_exited(button: Button) -> void:
	if upgrade_hover_tweens.has(button):
		var old: Tween = upgrade_hover_tweens[button]
		if old.is_valid():
			old.kill()
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
