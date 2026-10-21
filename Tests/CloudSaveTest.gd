
extends Node


func _ready() -> void:
	if not PlayerService.is_authenticated:
		print("CLOUD SAVE TEST: Not signed in.")
		return

	print("CLOUD SAVE TEST: Starting save download...")
	PlayerService.save_loaded.connect(_on_save_loaded)
	PlayerService.save_saved.connect(_on_save_saved)

	PlayerService.load_save()


func _on_save_loaded(success: bool, message: String) -> void:
	print("CLOUD SAVE LOAD: ", success, " — ", message)

	if not success:
		return

	PlayerService.player_save.currency = 123
	PlayerService.save_save()


func _on_save_saved(success: bool, message: String) -> void:
	print("CLOUD SAVE UPLOAD: ", success, " — ", message)
