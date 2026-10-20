@tool
extends EditorPlugin

const FinderDockScene = preload("res://addons/unused_resource_finder/finder_dock.tscn")

var _dock: Control

func _enter_tree() -> void:
	_dock = FinderDockScene.instantiate()
	_dock.editor_interface = get_editor_interface()
	add_control_to_dock(DOCK_SLOT_LEFT_BR, _dock)

func _exit_tree() -> void:
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
