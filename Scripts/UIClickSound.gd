extends AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	_connect_buttons(get_tree().root)


func _connect_buttons(node: Node) -> void:
	if node is BaseButton:
		_connect_button(node)

	for child in node.get_children():
		_connect_buttons(child)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_connect_button(node)


func _connect_button(button: BaseButton) -> void:
	if not button.pressed.is_connected(_play_click):
		button.pressed.connect(_play_click)


func _play_click() -> void:
	play()
