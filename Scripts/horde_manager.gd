extends Node

# One physics callback for all regular, charger, stalker and brute enemies.
# Boss AI remains on its original controller.
var enemies: Array[Node3D] = []
var enemy_indices: Dictionary = {}

func register_enemy(enemy: Node3D) -> void:
	if enemy_indices.has(enemy.get_instance_id()):
		return
		print("registered", enemy.name)
	enemy_indices[enemy.get_instance_id()] = enemies.size()
	enemies.append(enemy)

func unregister_enemy(enemy: Node3D) -> void:
	var id := enemy.get_instance_id()
	if not enemy_indices.has(id):
		return
	var index: int = enemy_indices[id]
	var last_index := enemies.size() - 1
	if index != last_index:
		var last_enemy := enemies[last_index]
		enemies[index] = last_enemy
		enemy_indices[last_enemy.get_instance_id()] = index
	enemies.pop_back()
	enemy_indices.erase(id)

func _physics_process(delta: float) -> void:
	# Iterate backwards: enemies can die and unregister during the tick.
	var i := enemies.size() - 1
	while i >= 0:
		if i < enemies.size():
			var enemy := enemies[i]
			if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
				if not enemy.has_meta("debug_checked"):
					enemy.set_meta("debug_checked", true)
					print("horde step: ", enemy.name)
					print("player found: ", enemy.get("player") != null)
					
				enemy.call("_horde_step", delta)
			
		i -= 1
