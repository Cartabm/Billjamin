extends Node3D

@export_group("Projectile")
@export var speed: float = 10.2
@export var damage: int = 10
@export var max_travel_distance: float = 20.0
@export var hit_radius: float = 0.18
@export_flags_3d_physics var hit_mask: int = 7

var direction: Vector3 = Vector3.FORWARD
var target_player: CharacterBody3D
var distance_traveled: float = 0.0

var _hit_sphere: SphereShape3D


func _ready() -> void:
	_hit_sphere = SphereShape3D.new()
	_hit_sphere.radius = maxf(hit_radius, 0.01)

	var visual := MeshInstance3D.new()
	visual.name = "ProjectileVisual"

	var mesh := SphereMesh.new()
	mesh.radius = _hit_sphere.radius
	mesh.height = _hit_sphere.radius * 2.0
	visual.mesh = mesh

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.35, 0.08)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.25, 0.02)
	material.emission_energy_multiplier = 2.0
	visual.material_override = material
	add_child(visual)

	# Enemy shots travel horizontally, as in the original script.
	direction.y = 0.0
	direction = direction.normalized()


func _physics_process(delta: float) -> void:
	var remaining_distance := max_travel_distance - distance_traveled
	if remaining_distance <= 0.0 or direction.is_zero_approx():
		queue_free()
		return

	var travel_distance := minf(maxf(speed, 0.0) * delta, remaining_distance)
	if travel_distance <= 0.0:
		return

	# Small steps prevent a fast-moving sphere from skipping a thin target.
	var step_count := maxi(1, ceili(travel_distance / maxf(_hit_sphere.radius * 0.5, 0.01)))
	var step_distance := travel_distance / float(step_count)

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _hit_sphere
	query.collision_mask = hit_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false

	# Exclude enemy bodies without requiring their collision layers to change.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy is CollisionObject3D:
			query.exclude.append(enemy.get_rid())

	var space_state := get_world_3d().direct_space_state

	for _step_index in range(step_count):
		var next_position := global_position + direction * step_distance
		query.transform = Transform3D(Basis.IDENTITY, next_position)

		# Ignore unrelated CharacterBody3D instances, matching the old behavior.
		# Requery so those bodies cannot hide a player or wall collision.
		for _attempt in range(32):
			var hits := space_state.intersect_shape(query, 32)
			if hits.is_empty():
				break

			var ignored_any := false
			for hit in hits:
				var collider: Object = hit.get("collider")
				if not is_instance_valid(collider):
					continue

				if is_instance_valid(target_player) and collider == target_player:
					if target_player.has_method("take_damage"):
						target_player.take_damage(damage)
					queue_free()
					return

				if collider is CharacterBody3D:
					var body := collider as CharacterBody3D
					if not query.exclude.has(body.get_rid()):
						query.exclude.append(body.get_rid())
						ignored_any = true
					continue

				# World geometry stops the shot.
				queue_free()
				return

			if not ignored_any:
				break

		global_position = next_position
		distance_traveled += step_distance

	if distance_traveled >= max_travel_distance - 0.0001:
		queue_free()
