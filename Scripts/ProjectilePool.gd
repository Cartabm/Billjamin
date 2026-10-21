
extends Node

const PROJECTILE_SCENE: PackedScene = preload("res://Scenes/projectile.tscn")

@export var initial_pool_size: int = 100

var available_projectiles: Array[Area3D] = []
var all_projectiles: Array[Area3D] = []


func _ready() -> void:
	for i in range(initial_pool_size):
		_create_projectile()


func _create_projectile() -> Area3D:
	var projectile := PROJECTILE_SCENE.instantiate() as Area3D

	if projectile == null:
		push_error("ProjectilePool: Could not instantiate projectile.")
		return null

	add_child(projectile)

	projectile.set_process(false)
	projectile.set_physics_process(false)
	projectile.visible = false

	all_projectiles.append(projectile)
	available_projectiles.append(projectile)

	return projectile


func get_projectile() -> Area3D:
	var projectile: Area3D

	if available_projectiles.is_empty():
		projectile = _create_projectile()

		if projectile == null:
			return null

	# Remove it from the available collection.
	projectile = available_projectiles.pop_back()

	projectile.visible = true
	projectile.set_process(true)
	projectile.set_physics_process(true)

	return projectile


func return_projectile(projectile: Area3D) -> void:
	if not is_instance_valid(projectile):
		return

	if available_projectiles.has(projectile):
		return

	projectile.set_process(false)
	projectile.set_physics_process(false)
	projectile.visible = false

	available_projectiles.append(projectile)
