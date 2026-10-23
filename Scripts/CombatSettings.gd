
extends Node

var auto_targeting_enabled: bool = true

const SETTINGS_PATH := "user://settings.cfg"


func _ready() -> void:
	var config := ConfigFile.new()

	if config.load(SETTINGS_PATH) == OK:
		auto_targeting_enabled = bool(
			config.get_value(
				"combat",
				"auto_targeting",
				true
			)
		)


func set_auto_targeting(enabled: bool) -> void:
	auto_targeting_enabled = enabled

	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)

	config.set_value(
		"combat",
		"auto_targeting",
		enabled
	)

	var error := config.save(SETTINGS_PATH)

	if error != OK:
		push_error("CombatSettings: Failed to save settings.")
