
extends Node

## Centralized physics processing for regular enemies.
## Boss AI remains on its own controller.

@export_group("Debug")
@export var debug_logging: bool = false

var enemies: Array[Node3D] = []
var enemy_indices: Dictionary = {}


func register_enemy(enemy: Node3D) -> void:
	if not is_instance_valid(enemy):
		return

	var id: int = enemy.get_instance_id()

	if enemy_indices.has(id):
		return

	enemy_indices[id] = enemies.size()
	enemies.append(enemy)

	if debug_logging:
		print("HordeManager registered: ", enemy.name)


func unregister_enemy(enemy: Node3D) -> void:
	if not is_instance_valid(enemy):
		return

	var id: int = enemy.get_instance_id()

	if not enemy_indices.has(id):
		return

	var index: int = enemy_indices[id]
	var last_index: int = enemies.size() - 1

	if index != last_index:
		var last_enemy: Node3D = enemies[last_index]
		enemies[index] = last_enemy
		enemy_indices[last_enemy.get_instance_id()] = index

	enemies.pop_back()
	enemy_indices.erase(id)

	if debug_logging:
		print("HordeManager unregistered: ", enemy.name)


func _physics_process(delta: float) -> void:
	var i: int = enemies.size() - 1

	while i >= 0:
		if i < enemies.size():
			var enemy: Node3D = enemies[i]

			if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
				enemy.call("_horde_step", delta)

		i -= 1


func get_active_enemy_count() -> int:
	return enemies.size()
