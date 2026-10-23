@tool
extends EditorPlugin

var creator_dock: Control

func _enter_tree() -> void:
	var dock_script: Script = load("res://addons/upgrade_creator/upgrade_creator_dock.gd")
	creator_dock = dock_script.new()
	creator_dock.name = "Upgrade Creator"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, creator_dock)

func _exit_tree() -> void:
	if is_instance_valid(creator_dock):
		remove_control_from_docks(creator_dock)
		creator_dock.queue_free()
