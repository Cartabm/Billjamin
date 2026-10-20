extends RefCounted

# Applies dimensions to the existing named wall pieces and their colliders.
# All positions are local to the unrotated room scene.
static func resize_room(room: Node3D, room_size: float, doorway_width: float = 4.0) -> void:
	var half := room_size * 0.5
	var segment_length := (room_size - doorway_width) * 0.5
	var segment_center := doorway_width * 0.5 + segment_length * 0.5
	for body in room.get_children():
		if not body is StaticBody3D:
			continue
		var body_name := String(body.name).to_lower()
		var position_2d := Vector2.ZERO
		var dimensions := Vector3.ZERO
		if body_name == "roomfloor":
			position_2d = Vector2.ZERO
			dimensions = Vector3(room_size, 0.5, room_size)
		else:
			var side := ""
			if body_name.begins_with("northwall"):
				side = "north"
			elif body_name.begins_with("southwall"):
				side = "south"
			elif body_name.begins_with("eastwall"):
				side = "east"
			elif body_name.begins_with("westwall"):
				side = "west"
			else:
				continue
			var offset := 0.0
			if body_name.ends_with("left") or body_name.ends_with("north"):
				offset = -segment_center
			elif body_name.ends_with("right") or body_name.ends_with("south"):
				offset = segment_center
			var has_opening := not is_zero_approx(offset)
			var length := segment_length if has_opening else room_size
			if side == "north":
				position_2d = Vector2(offset, -half)
				dimensions = Vector3(length, 5.0, 1.0)
			elif side == "south":
				position_2d = Vector2(offset, half)
				dimensions = Vector3(length, 5.0, 1.0)
			elif side == "east":
				position_2d = Vector2(half, offset)
				dimensions = Vector3(1.0, 5.0, length)
			else:
				position_2d = Vector2(-half, offset)
				dimensions = Vector3(1.0, 5.0, length)
		for child in body.get_children():
			if child is MeshInstance3D and child.mesh is BoxMesh:
				child.mesh = child.mesh.duplicate()
				child.mesh.size = dimensions
				child.position = Vector3(position_2d.x, -0.25 if body_name == "roomfloor" else 2.5, position_2d.y)
			elif child is CollisionShape3D and child.shape is BoxShape3D:
				child.shape = child.shape.duplicate()
				child.shape.size = dimensions
				child.position = Vector3(position_2d.x, -0.25 if body_name == "roomfloor" else 2.5, position_2d.y)
