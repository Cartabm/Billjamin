extends Node3D

@onready var spawn_point: Marker3D = $PlayerSpawnPoint


func _ready() -> void:
	call_deferred("spawn_selected_player")


func spawn_selected_player() -> void:
	if not CharacterManager.has_selected_character():
		push_warning("PlayerSpawner: No character selected.")
		return

	var selected_scene: PackedScene = CharacterManager.get_selected_player_scene()

	if selected_scene == null:
		push_error("PlayerSpawner: No playable character scene found.")
		return

	# Prevent duplicate player instances.
	if get_tree().current_scene.get_node_or_null("Player") != null:
		push_warning("PlayerSpawner: Player already exists.")
		return

	var player: Node3D = selected_scene.instantiate() as Node3D

	if player == null:
		push_error("PlayerSpawner: Selected scene must have a Node3D root.")
		return

	player.name = "Player"

	get_tree().current_scene.add_child(player)
	player.global_transform = spawn_point.global_transform

	print(
		"Spawned character: ",
		CharacterManager.selected_character_name,
		" | Class: ",
		CharacterManager.CharacterClass.keys()[CharacterManager.selected_class]
	)
