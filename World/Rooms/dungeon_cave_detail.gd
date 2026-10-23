extends RefCounted

# First-pass mine dressing. Adds low-poly, collidable rock formations
# along existing wall segments without changing room floors or doorways.
# Called after the room has been resized and its materials assigned.
static func decorate_room(room: Node3D, rng: RandomNumberGenerator) -> void:
	var rock_group := Node3D.new()
	rock_group.name = "ProceduralRockFaces"
	room.add_child(rock_group)

	for body in room.get_children():
		if not body is StaticBody3D:
			continue
		var wall_name := String(body.name).to_lower()
		if not (wall_name.begins_with("northwall") or wall_name.begins_with("southwall") or wall_name.begins_with("eastwall") or wall_name.begins_with("westwall")):
			continue

		var wall_mesh := body.get_node_or_null("MeshInstance3D") as MeshInstance3D
		if wall_mesh == null or not wall_mesh.mesh is BoxMesh:
			continue

		var box := wall_mesh.mesh as BoxMesh
		var along_x := wall_name.begins_with("northwall") or wall_name.begins_with("southwall")
		var length: float = box.size.x if along_x else box.size.z
		var segment_center: Vector3 = body.position + wall_mesh.position
		var wall_material: Material = wall_mesh.material_override

		# Leave a generous margin at every segment end, particularly doorways.
		var usable_length: float = length - 3.0
		if usable_length <= 1.0:
			continue
		var count: int = maxi(1, floori(usable_length / 2.1))
		for i in range(count):
			var t: float = (float(i) + 0.5) / float(count)
			var offset: float = (t - 0.5) * usable_length
			offset += rng.randf_range(-0.22, 0.22)
			var radius: float = rng.randf_range(0.65, 1.05)
			var rock_height: float = rng.randf_range(2.0, 4.6)
			var rock_position := Vector3(segment_center.x, rock_height * 0.5, segment_center.z)
			if along_x:
				rock_position.x += offset
				rock_position.z += 0.18 if wall_name.begins_with("northwall") else -0.18
			else:
				rock_position.z += offset
				rock_position.x += -0.18 if wall_name.begins_with("eastwall") else 0.18

			var rock := StaticBody3D.new()
			rock.name = "CaveRock"
			rock.position = rock_position
			rock.rotation.y = rng.randf_range(-0.45, 0.45)
			rock_group.add_child(rock)

			var mesh_instance := MeshInstance3D.new()
			var mesh := SphereMesh.new()
			mesh.radius = radius
			mesh.height = rock_height
			mesh.radial_segments = 7
			mesh.rings = 4
			mesh_instance.mesh = mesh
			mesh_instance.material_override = wall_material
			rock.add_child(mesh_instance)

			var collider := CollisionShape3D.new()
			var shape := CapsuleShape3D.new()
			shape.radius = radius * 0.85
			shape.height = maxf(rock_height, shape.radius * 2.0)
			collider.shape = shape
			rock.add_child(collider)
