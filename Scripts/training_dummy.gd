
extends CharacterBody3D

@export var max_health: int = 100000

var health: int



func _ready() -> void:
	add_to_group("enemies")

	print("DUMMY READY FIRED")
	print("=== TRAINING DUMMY SCRIPT RUNNING ===")
	print("Node name: ", name)
	print("Script: ", get_script())

	var shape_node := get_node_or_null("CollisionShape3D") as CollisionShape3D
	print("Layer: ", collision_layer)
	print("Mask: ", collision_mask)
	print("Shape exists: ", shape_node != null)

	if shape_node:
		print("Shape disabled: ", shape_node.disabled)
		print("Shape resource: ", shape_node.shape)

	health = max_health
	set_process(false)
	set_physics_process(false)

	for node in find_children("*", "", true, false):
		if node is Timer:
			node.stop()
		node.set_process(false)
		node.set_physics_process(false)

	print("TRAINING DUMMY READY | Health: ", health)



func take_damage(amount: int) -> void:
	health = maxi(health - amount, 0)
	print("TRAINING DUMMY HIT | Damage: ", amount, " | Health: ", health, "/", max_health)

	if health <= 0:
		print("TRAINING DUMMY DEFEATED")
		queue_free()
