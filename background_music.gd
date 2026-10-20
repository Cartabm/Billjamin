
extends AudioStreamPlayer

const SETTINGS_PATH := "user://audio_settings.cfg"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_audio_settings()


func load_audio_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)

	var master_percent: float = 50.0
	var music_percent: float = 50.0

	if err == OK:
		master_percent = config.get_value(
			"audio", "master_volume", 50.0
		)
		music_percent = config.get_value(
			"audio", "music_volume", 50.0
		)

	set_bus_percent("Master", master_percent)
	set_bus_percent("Music", music_percent)


func save_audio_settings() -> void:
	var config := ConfigFile.new()

	config.set_value(
		"audio", "master_volume", get_bus_percent("Master")
	)
	config.set_value(
		"audio", "music_volume", get_bus_percent("Music")
	)

	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_error("Failed to save audio settings.")


func set_bus_percent(bus_name: String, percent: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		push_error("Audio bus not found: " + bus_name)
		return

	if percent <= 0.0:
		AudioServer.set_bus_volume_db(bus_index, -80.0)
	else:
		AudioServer.set_bus_volume_db(
			bus_index, linear_to_db(percent / 100.0)
		)


func get_bus_percent(bus_name: String) -> float:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return 50.0

	var current_bus_db := AudioServer.get_bus_volume_db(bus_index)
	if current_bus_db <= -80.0:
		return 0.0

	return clampf(db_to_linear(current_bus_db) * 100.0, 0.0, 100.0)
