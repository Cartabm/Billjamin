
extends Node3D

@export var archer_scene: PackedScene = preload("res://Scenes/player.tscn")
@export var rogue_scene: PackedScene = preload("res://Scenes/RoguePlayer.tscn")

@onready var spawn_point: Marker3D = $PlayerSpawnPoint


func _ready() -> void:
	call_deferred("spawn_selected_player")


func spawn_selected_player() -> void:
	var selected_scene: PackedScene = archer_scene

	if CharacterManager.selected_class == CharacterManager.CharacterClass.ROGUE:
		selected_scene = rogue_scene

	if selected_scene == null:
		push_error("PlayerSpawner: No character scene assigned.")
		return

	var player = selected_scene.instantiate()
	player.name = "Player"

	get_tree().current_scene.add_child(player)
	player.global_transform = spawn_point.global_transform

	print("Spawned character: ", player.name)
