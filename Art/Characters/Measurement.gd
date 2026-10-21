extends Node3D

func _ready() -> void:
	var bounds: AABB
	var found_mesh := false

	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue

		var mesh_bounds := mesh_instance.get_aabb()
		var mesh_transform := global_transform.affine_inverse() * mesh_instance.global_transform
		mesh_bounds = mesh_transform * mesh_bounds

		if not found_mesh:
			bounds = mesh_bounds
			found_mesh = true
		else:
			bounds = bounds.merge(mesh_bounds)

	if found_mesh:
		print("Character model height: ", bounds.size.y)
		print("Suggested uniform scale: ", 1.6 / bounds.size.y)
	else:
		print("No mesh found.")
