
extends Control

@onready var master_slider: HSlider = $CenterContainer/VBoxContainer/MasterSlider
@onready var music_slider: HSlider = $CenterContainer/VBoxContainer/MusicSlider
@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton
@onready var rotate_minimap_check: CheckButton = \
	$CenterContainer/VBoxContainer/RotateMinimapCheckButton

var return_to: String = "res://MainMenu.tscn"
var opened_from_pause_menu: bool = false

func _ready() -> void:
	master_slider.value = db_to_linear(
		AudioServer.get_bus_volume_db(
			AudioServer.get_bus_index("Master")
		)
	) * 100.0

	music_slider.value = db_to_linear(
		AudioServer.get_bus_volume_db(
			AudioServer.get_bus_index("Music")
		)
	) * 100.0
	
	var config := ConfigFile.new()
	var error := config.load("user://settings.cfg")
	
	rotate_minimap_check.button_pressed = false
	
	if error == OK:
		rotate_minimap_check.button_pressed = config.get_value(
			"minimap",
			"rotate",
			false
		)
	rotate_minimap_check.toggled.connect(
		_on_rotate_minimap_toggled
	)
	master_slider.value_changed.connect(_on_master_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	back_button.pressed.connect(_on_back_button_pressed)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _on_master_volume_changed(value: float) -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(
		bus_index,
		linear_to_db(value / 100.0) if value > 0.0 else -80.0
	)
	get_node("/root/BackgroundMusic").save_audio_settings()


func _on_music_volume_changed(value: float) -> void:
	var bus_index := AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(
		bus_index,
		linear_to_db(value / 100.0) if value > 0.0 else -80.0
	)
	get_node("/root/BackgroundMusic").save_audio_settings()



func _on_back_button_pressed() -> void:
	if opened_from_pause_menu:
		queue_free()
	else:
		get_tree().change_scene_to_file("res://MainMenu.tscn")
		

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_button_pressed()
		get_viewport().set_input_as_handled()

func _on_rotate_minimap_toggled(enabled: bool) -> void:
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	
	config.set_value("minimap", "rotate", enabled)
	config.save("user://settings.cfg")
	
	var minimap = get_tree().get_first_node_in_group("minimap")
	
	if minimap != null:
		minimap.set_rotation_enabled(enabled)
	
