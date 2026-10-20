
extends CanvasLayer

@onready var pause_menu: Control = $PauseMenu
@onready var return_button: Button = $PauseMenu/CenterContainer/CenterVBox/ReturnToMenuButton
@onready var options_button: Button = $PauseMenu/CenterContainer/CenterVBox/OptionsButton
@onready var quit_button: Button = $PauseMenu/CenterContainer/CenterVBox/QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.hide()

	return_button.pressed.connect(_on_return_to_menu_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
			pause_menu.visible = not pause_menu.visible
			get_tree().paused = pause_menu.visible
			get_viewport().set_input_as_handled()


func _on_return_to_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://MainMenu.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
	

func _on_options_pressed() -> void:
	pause_menu.hide()

	var options_scene = load("res://optionsmenu.tscn").instantiate()
	options_scene.opened_from_pause_menu = true
	options_scene.process_mode = Node.PROCESS_MODE_ALWAYS
	options_scene.tree_exiting.connect(_on_options_closed)

	get_tree().root.add_child(options_scene)


func _on_options_closed() -> void:
	if is_instance_valid(pause_menu):
		pause_menu.show()
