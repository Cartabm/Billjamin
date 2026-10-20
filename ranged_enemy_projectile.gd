extends Node3D

@export var speed: float = 12.0
@export var damage: int = 10
@export var lifetime: float = 3.0
@export_flags_3d_physics var hit_mask: int = 5  # Layer 1 (player) + layer 3 (world)

var direction: Vector3 = Vector3.FORWARD
var target_player: CharacterBody3D


func _ready() -> void:
	# Visible glowing bolt; no extra meshes or textures required.
	var visual := MeshInstance3D.new()
	visual.name = "ProjectileVisual"
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.36
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.35, 0.08)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.25, 0.02)
	material.emission_energy_multiplier = 2.0
	visual.material_override = material
	add_child(visual)


func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return

	var step: Vector3 = direction * speed * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + step, hit_mask)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)

	if not hit.is_empty():
		var collider: Object = hit["collider"]
		if is_instance_valid(target_player) and collider == target_player:
			if target_player.has_method("take_damage"):
				target_player.take_damage(damage)
		queue_free()
		return

	global_position += step
