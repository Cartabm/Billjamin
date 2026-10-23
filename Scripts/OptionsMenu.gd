
extends Control

@onready var master_slider: HSlider = $CenterContainer/VBoxContainer/MasterSlider
@onready var music_slider: HSlider = $CenterContainer/VBoxContainer/MusicSlider
@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton

@onready var rotate_minimap_check: CheckButton = \
	$CenterContainer/VBoxContainer/RotateMinimapCheckButton

@onready var auto_targeting_check: CheckButton = \
	$CenterContainer/VBoxContainer/AutoTargetingCheckButton


var return_to: String = "res://Scenes/MainMenu.tscn"
var opened_from_pause_menu: bool = false

const SETTINGS_PATH: String = "user://settings.cfg"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# ==========================================
	# MASTER VOLUME
	# ==========================================

	var master_bus := AudioServer.get_bus_index("Master")

	if master_bus >= 0:
		master_slider.value = db_to_linear(
			AudioServer.get_bus_volume_db(master_bus)
		) * 100.0

	# ==========================================
	# MUSIC VOLUME
	# ==========================================

	var music_bus := AudioServer.get_bus_index("Music")

	if music_bus >= 0:
		music_slider.value = db_to_linear(
			AudioServer.get_bus_volume_db(music_bus)
		) * 100.0

	# ==========================================
	# LOAD MINIMAP SETTINGS
	# ==========================================

	var config := ConfigFile.new()
	var error := config.load(SETTINGS_PATH)

	var rotate_enabled: bool = false

	if error == OK:
		rotate_enabled = bool(
			config.get_value(
				"minimap",
				"rotate",
				false
			)
		)

	rotate_minimap_check.set_pressed_no_signal(
		rotate_enabled
	)

	# ==========================================
	# LOAD AUTO TARGETING SETTINGS
	# ==========================================

	var combat_settings: Node = get_node_or_null(
		"/root/CombatSettings"
	)

	if combat_settings != null:
		auto_targeting_check.set_pressed_no_signal(
			bool(combat_settings.get("auto_targeting_enabled"))
		)
	else:
		push_warning(
			"OptionsMenu: CombatSettings Autoload not found."
		)
		auto_targeting_check.set_pressed_no_signal(true)

	# ==========================================
	# CONNECT BUTTONS AND SLIDERS
	# ==========================================

	master_slider.value_changed.connect(
		_on_master_volume_changed
	)

	music_slider.value_changed.connect(
		_on_music_volume_changed
	)

	rotate_minimap_check.toggled.connect(
		_on_rotate_minimap_toggled
	)

	auto_targeting_check.toggled.connect(
		_on_auto_targeting_toggled
	)

	back_button.pressed.connect(
		_on_back_button_pressed
	)


# ==========================================
# MASTER VOLUME
# ==========================================

func _on_master_volume_changed(value: float) -> void:
	var bus_index := AudioServer.get_bus_index("Master")

	if bus_index < 0:
		return

	AudioServer.set_bus_volume_db(
		bus_index,
		linear_to_db(value / 100.0) if value > 0.0 else -80.0
	)

	get_node("/root/BackgroundMusic").save_audio_settings()


# ==========================================
# MUSIC VOLUME
# ==========================================

func _on_music_volume_changed(value: float) -> void:
	var bus_index := AudioServer.get_bus_index("Music")

	if bus_index < 0:
		return

	AudioServer.set_bus_volume_db(
		bus_index,
		linear_to_db(value / 100.0) if value > 0.0 else -80.0
	)

	get_node("/root/BackgroundMusic").save_audio_settings()


# ==========================================
# MINIMAP ROTATION
# ==========================================

func _on_rotate_minimap_toggled(enabled: bool) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)

	config.set_value(
		"minimap",
		"rotate",
		enabled
	)

	config.save(SETTINGS_PATH)

	var minimap := get_tree().get_first_node_in_group(
		"minimap"
	)

	if minimap != null:
		minimap.set_rotation_enabled(enabled)


# ==========================================
# AUTO TARGETING
# ==========================================

func _on_auto_targeting_toggled(enabled: bool) -> void:
	var combat_settings := get_node_or_null("/root/CombatSettings")

	if combat_settings == null:
		push_error("CombatSettings Autoload not found!")
		return

	combat_settings.call("set_auto_targeting", enabled)

	var config := ConfigFile.new()
	var error := config.load("user://settings.cfg")

	print("Checkbox changed to: ", enabled)
	print("Global setting: ", combat_settings.get("auto_targeting_enabled"))

	if error == OK:
		print("Saved setting: ", config.get_value("combat", "auto_targeting", "MISSING"))
	else:
		print("Settings file error: ", error)


# ==========================================
# BACK BUTTON
# ==========================================

func _on_back_button_pressed() -> void:
	if opened_from_pause_menu:
		queue_free()
	else:
		get_tree().paused = false
		get_tree().change_scene_to_file(
			"res://Scenes/MainMenu.tscn"
		)


# ==========================================
# ESC KEY
# ==========================================

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_button_pressed()
		get_viewport().set_input_as_handled()
