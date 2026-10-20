
extends Node3D

func _ready() -> void:
	for child in find_children("*", "MeshInstance3D", true, false):
		var mesh_node := child as MeshInstance3D
		if mesh_node.mesh == null:
			continue

		var bounds := mesh_node.get_aabb()
		var scaled_bounds := mesh_node.global_transform.basis * bounds.size

		print(
			mesh_node.name,
			" | Mesh size: ", bounds.size,
			" | Transformed size: ", scaled_bounds.abs()
		)
