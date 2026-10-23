@tool
extends EditorPlugin

var item_dock: Control

func _enter_tree() -> void:
	var dock_script: Script = load("res://addons/item_creator/item_creator_dock.gd")
	if dock_script == null:
		push_error("Item Creator: dock script missing")
		return
	item_dock = dock_script.new()
	item_dock.name = "Item Creator"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, item_dock)

func _exit_tree() -> void:
	if is_instance_valid(item_dock):
		remove_control_from_docks(item_dock)
		item_dock.queue_free()
