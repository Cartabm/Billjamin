extends Node

const OVERWORLD_SCENE: String = "res://Art/Environment/OverworldTest.tscn"

var has_return_point: bool = false
var return_position: Vector3 = Vector3.ZERO

func remember_entrance(position: Vector3) -> void:
	return_position = position
	has_return_point = true

func return_to_overworld() -> void:
	if not has_return_point:
		push_warning("DungeonReturnState: No house return point saved. Enter through a house first.")
		return
	var err: Error = get_tree().change_scene_to_file(OVERWORLD_SCENE)
	if err != OK:
		push_error("DungeonReturnState: Could not load overworld: %s" % OVERWORLD_SCENE)
		return
	await get_tree().scene_changed
	var scene: Node = get_tree().current_scene
	var rogue: Node3D = scene.get_node_or_null("TestPlayer") as Node3D
	if rogue == null:
		push_error("DungeonReturnState: TestPlayer not found directly under OverworldTest.")
		return
	rogue.global_position = return_position
	if rogue is CharacterBody3D:
		(rogue as CharacterBody3D).velocity = Vector3.ZERO
