extends Node3D


func _enter_tree() -> void:
	if not CharacterManager.has_selected_character():
		push_warning("Overworld: No character selected.")
		return

	var player_scene: PackedScene = CharacterManager.get_selected_player_scene()

	if player_scene == null:
		push_error("Overworld: No selected player scene.")
		return

	# Find the existing hardcoded Rogue.
	var old_player := get_node_or_null("TestPlayer")

	# Save the old player reference before removing it.
	if old_player != null:
		remove_child(old_player)
		old_player.queue_free()

	# Create the character selected at login.
	var player := player_scene.instantiate() as CharacterBody3D

	if player == null:
		push_error("Overworld: Player scene must have a CharacterBody3D root.")
		return

	player.name = "Player"

	# Set position BEFORE adding the player to the scene tree.
	var spawn_point := get_node_or_null("PlayerSpawnPoint") as Marker3D

	if spawn_point != null:
		player.transform = spawn_point.transform
	else:
		push_warning("Overworld: PlayerSpawnPoint not found.")

	add_child(player)

	# Assign the new player to the terrain generator.
	var generator := get_node_or_null("OverworldGenerator")

	if generator != null:
		generator.set("player", player)

	print(
		"OVERWORLD PLAYER SPAWNED: ",
		CharacterManager.selected_character_name
	)
