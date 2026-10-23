extends Node3D

func _enter_tree() -> void:
	if not CharacterManager.has_selected_character():
		push_warning("Arena: No character selected.")
		return

	var player_scene: PackedScene = CharacterManager.get_selected_player_scene()

	if player_scene == null:
		push_error("Arena: Selected player scene not found.")
		return

	var old_player := get_node_or_null("Player")

	if old_player != null:
		remove_child(old_player)
		old_player.queue_free()

	var player := player_scene.instantiate() as CharacterBody3D

	if player == null:
		push_error("Arena: Player scene must have a CharacterBody3D root.")
		return

	player.name = "Player"

	var spawn_point := get_node_or_null("PlayerSpawn") as Marker3D

	if spawn_point != null:
		player.transform = spawn_point.transform

	add_child(player)

	print("ARENA PLAYER SPAWNED: ", CharacterManager.selected_character_name)
