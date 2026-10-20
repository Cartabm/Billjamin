extends Area3D

@export var speed: float = 18.0
@export var lifetime: float = 2.0
@export var damage: int = 1
@export var hit_radius: float = 0.2
@export var ricochet_range: float = 12.0

# Assigned by player.gd when the arrow is spawned. Never more than 3.
var ricochet_bounces: int = 0
var direction: Vector3 = Vector3.FORWARD
var age: float = 0.0
var has_hit: bool = false

var hit_shape: SphereShape3D
var hit_query: PhysicsShapeQueryParameters3D
var player_node: Node
var hit_targets: Array[Node] = []
var bounce_target: Node3D = null


func _ready() -> void:
	monitoring = false
	monitorable = false

	hit_shape = SphereShape3D.new()
	hit_shape.radius = maxf(hit_radius, 0.05)

	hit_query = PhysicsShapeQueryParameters3D.new()
	hit_query.shape = hit_shape
	hit_query.collision_mask = 3
	hit_query.collide_with_bodies = true
	hit_query.collide_with_areas = false
	hit_query.exclude = [get_rid()]

	player_node = get_tree().current_scene.get_node_or_null("Player")

	var arrow_sprite := get_node_or_null("FireballSprite") as AnimatedSprite3D
	if arrow_sprite != null:
		arrow_sprite.visible = true
		arrow_sprite.scale = Vector3(4.0, 4.0, 4.0)
		arrow_sprite.play(&"default")


func _physics_process(delta: float) -> void:
	if has_hit:
		return

	age += delta
	if age >= lifetime:
		queue_free()
		return

	# Keep tracking the chosen target as it moves.
	if bounce_target != null:
		if not is_instance_valid(bounce_target) or not bounce_target.is_inside_tree():
			bounce_target = _nearest_unhit_enemy()
		if bounce_target != null:
			var aim := bounce_target.global_position - global_position
			aim.y = 0.0
			if aim.length_squared() > 0.0001:
				direction = aim.normalized()
				update_arrow_visual()

	var start: Vector3 = global_position
	var motion: Vector3 = direction.normalized() * speed * delta
	if motion.length_squared() <= 0.000001:
		return

	var space := get_world_3d().direct_space_state

	hit_query.motion = Vector3.ZERO
	hit_query.transform = Transform3D(Basis.IDENTITY, start)
	var starting_hits := space.intersect_shape(hit_query, 32)
	if _handle_collision_results(starting_hits):
		return

	hit_query.transform = Transform3D(Basis.IDENTITY, start)
	hit_query.motion = motion
	var fractions: PackedFloat32Array = space.cast_motion(hit_query)

	if fractions.size() < 2 or fractions[0] >= 1.0:
		global_position = start + motion
		return

	var safe_fraction: float = fractions[0]
	var unsafe_fraction: float = fractions[1]
	var impact_position: Vector3 = start + motion * unsafe_fraction

	hit_query.motion = Vector3.ZERO
	hit_query.transform = Transform3D(Basis.IDENTITY, impact_position)
	var impact_hits := space.intersect_shape(hit_query, 32)
	if _handle_collision_results(impact_hits):
		return

	var probe_fraction: float = minf(unsafe_fraction + 0.01, 1.0)
	var probe_position: Vector3 = start + motion * probe_fraction
	hit_query.transform = Transform3D(Basis.IDENTITY, probe_position)
	var probe_hits := space.intersect_shape(hit_query, 32)
	if _handle_collision_results(probe_hits):
		return

	global_position = start + motion * safe_fraction
	has_hit = true
	queue_free()


func _handle_collision_results(results: Array[Dictionary]) -> bool:
	for result in results:
		var collider: Object = result.get("collider")
		if not is_instance_valid(collider) or _belongs_to_player(collider):
			continue
		var damage_target := _find_damage_target(collider)
		if damage_target != null:
			if hit_targets.has(damage_target):
				continue
			_apply_hit(damage_target)
			return true

	for result in results:
		var collider: Object = result.get("collider")
		if not is_instance_valid(collider) or _belongs_to_player(collider):
			continue
		if collider is PhysicsBody3D:
			# Already-hit enemies are excluded from future sweeps, but
			# also ignore them here if a child collider was returned.
			var old_target := _find_damage_target(collider)
			if old_target != null and hit_targets.has(old_target):
				continue
			has_hit = true
			queue_free()
			return true
	return false


func _belongs_to_player(collider: Object) -> bool:
	if player_node == null or not is_instance_valid(player_node):
		return false
	if not collider is Node:
		return false
	var node := collider as Node
	while node != null:
		if node == player_node:
			return true
		node = node.get_parent()
	return false


func _find_damage_target(collider: Object) -> Node:
	if not collider is Node:
		return null
	var node := collider as Node
	while node != null:
		if node.is_in_group("enemies") and node.has_method("take_damage"):
			return node
		node = node.get_parent()
	return null


func _apply_hit(target: Node) -> void:
	if has_hit or hit_targets.has(target):
		return

	hit_targets.append(target)
	# Exclude every collision body under the target, so a bounced
	# arrow cannot immediately hit the same enemy's collision again.
	_exclude_target_colliders(target)
	target.call("take_damage", damage)

	if ricochet_bounces <= 0:
		has_hit = true
		queue_free()
		return

	var next_target := _nearest_unhit_enemy()
	if next_target == null:
		has_hit = true
		queue_free()
		return

	ricochet_bounces -= 1
	bounce_target = next_target
	age = 0.0
	var aim := bounce_target.global_position - global_position
	aim.y = 0.0
	if aim.length_squared() > 0.0001:
		direction = aim.normalized()
		update_arrow_visual()


func _exclude_target_colliders(target: Node) -> void:
	var exclusions: Array[RID] = hit_query.exclude
	if target is CollisionObject3D:
		exclusions.append((target as CollisionObject3D).get_rid())
	for child in target.find_children("*", "CollisionObject3D", true, false):
		if child is CollisionObject3D:
			exclusions.append((child as CollisionObject3D).get_rid())
	hit_query.exclude = exclusions


func _nearest_unhit_enemy() -> Node3D:
	var nearest: Node3D = null
	var best_distance_sq := ricochet_range * ricochet_range
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not candidate is Node3D:
			continue
		if not candidate.has_method("take_damage") or hit_targets.has(candidate):
			continue
		if not candidate.is_inside_tree() or candidate.is_queued_for_deletion():
			continue
		var distance_sq := global_position.distance_squared_to(candidate.global_position)
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			nearest = candidate
	return nearest


func update_arrow_visual() -> void:
	var arrow_sprite := get_node_or_null("FireballSprite") as AnimatedSprite3D
	if arrow_sprite == null:
		return
	arrow_sprite.visible = true
	arrow_sprite.scale = Vector3(4.0, 4.0, 4.0)
	arrow_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	arrow_sprite.play(&"default")

	var active_camera := get_viewport().get_camera_3d()
	if active_camera == null:
		return
	var screen_x: float = direction.dot(active_camera.global_basis.x)
	var screen_y: float = direction.dot(active_camera.global_basis.y)
	if Vector2(screen_x, screen_y).length_squared() < 0.001:
		return
	var shot_angle: float = atan2(-screen_y, screen_x)
	var camera_basis: Basis = active_camera.global_basis
	var image_rotation := Basis(Vector3.FORWARD, shot_angle)
	arrow_sprite.global_basis = camera_basis * image_rotation
	arrow_sprite.scale = Vector3(4.0, 4.0, 4.0)


func _exit_tree() -> void:
	pass
