
extends CharacterBody3D

signal boss_defeated
const DAMAGE_NUMBER_SCENE = preload("res://Scenes/DamageNumber.tscn")
# ============================================================
# BOSS SETTINGS
# Scene tree:
# Boss (CharacterBody3D)
# ├── AnimatedSprite3D
# ├── MeshInstance3D
# ├── CollisionShape3D
# └── Healthbar
# ============================================================

const VISUAL_FLOOR_HEIGHT: float = 0.20
const VISUAL_FLOOR_Y: float = 0.20

@export_group("Health")
@export var boss_max_health: int = 100
@export var contact_damage: int = 80

@export_group("Player")
@export var player_node_path: NodePath
@export var player_detection_range: float = 60.0

@export_group("Movement")
@export var move_speed: float = 3.5
@export var acceleration: float = 18.0
@export var stopping_distance: float = 3.0
@export var strafe_speed: float = 2.5
@export var strafe_switch_interval: float = 2.0
@export var gravity: float = 24.0

@export_group("Dash Attack")
@export var charge_interval: float = 5.0
@export var charge_windup: float = 0.65
@export var charge_duration: float = 1.0
@export var charge_speed: float = 12.0
@export var charge_damage: int = 35
@export var charge_width: float = 2.0

@export_group("Ground Slam")
@export var slam_interval: float = 8.0
@export var slam_windup: float = 1.5
@export var slam_radius: float = 5.5
@export var slam_damage: int = 35
@export var slam_jump_height: float = 3.0
@export var impact_duration: float = 0.45
@export var impact_max_radius: float = 8.0

@export_group("Two-Slash Combo")
@export var combo_min_interval: float = 5.0
@export var combo_max_interval: float = 8.0
@export var combo_telegraph_duration: float = 0.5
@export var combo_slash_duration: float = 0.45
@export var combo_between_slashes: float = 0.2
@export var combo_damage: int = 35
@export var combo_cone_range: float = 16.0
@export var combo_cone_half_angle: float = 55.0
@export var combo_line_range: float = 16.0
@export var combo_line_width: float = 2.4
@export var combo_prediction_time: float = 0.35
@export var combo_max_prediction_distance: float = 3.0

@export_group("Animation Names")
@export var idle_animation: StringName = &"Idle"
@export var walk_animation: StringName = &"Walk"
@export var attack_animation: StringName = &"Attack01"
@export var death_animation: StringName = &"Death"

# ============================================================
# STATE
# ============================================================

var health: int
var dead: bool = false

var player: Node3D
var sprite: AnimatedSprite3D

var current_state: StringName = &"pursue"
var state_timer: float = 0.0

var charge_timer: float = 0.0
var slam_timer: float = 0.0
var combo_timer: float = 0.0
var slam_marker_material: StandardMaterial3D

var strafe_timer: float = 0.0
var strafe_direction: float = 1.0

var attack_direction: Vector3 = Vector3.FORWARD
var dash_direction: Vector3 = Vector3.FORWARD
var slam_start_position: Vector3
var slam_target: Vector3
var slam_progress: float = 0.0

var attack_has_hit: bool = false

# Ground slam warning visuals.
var slam_marker: MeshInstance3D
var slam_outer_ring: MeshInstance3D
var slam_inner_ring: MeshInstance3D
var slam_visual_time: float = 0.0

# Ground slam impact visual.
var impact_ring: MeshInstance3D
var impact_material: StandardMaterial3D
var impact_timer: float = 0.0
var impact_active: bool = false

# Cleave warning visuals.
var cone_mesh: MeshInstance3D
var line_mesh: MeshInstance3D

# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	add_to_group("enemies")
	health = boss_max_health

	sprite = get_node_or_null("AnimatedSprite3D") as AnimatedSprite3D

	_find_player()

	create_slam_visuals()
	create_impact_visual()
	create_combo_telegraphs()

	charge_timer = charge_interval * 0.6
	slam_timer = slam_interval * 0.4
	combo_timer = randf_range(
		combo_min_interval,
		combo_max_interval
	)

	_play_animation(idle_animation)


func _physics_process(delta: float) -> void:
	if dead:
		return

	if player == null or not is_instance_valid(player):
		_find_player()
		_apply_gravity(delta)
		move_and_slide()
		return

	var distance := _distance_to_player()

	if distance > player_detection_range:
		_apply_gravity(delta)
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		move_and_slide()
		_play_animation(idle_animation)
		return

	charge_timer += delta
	slam_timer += delta
	combo_timer -= delta
	strafe_timer -= delta

	if strafe_timer <= 0.0:
		strafe_timer = strafe_switch_interval
		strafe_direction *= -1.0

	match current_state:
		&"slam_windup":
			_process_slam_windup(delta)
			return

		&"slam_airborne":
			_process_slam_airborne(delta)
			return

		&"charge_windup":
			_process_charge_windup(delta)
			return

		&"charging":
			_process_charging(delta)
			return

		&"combo_cone_warning":
			_process_combo_warning(delta, true)
			return

		&"combo_cone_attack":
			_process_combo_attack(delta, true)
			return

		&"combo_pause":
			_process_combo_pause(delta)
			return

		&"combo_line_warning":
			_process_combo_warning(delta, false)
			return

		&"combo_line_attack":
			_process_combo_attack(delta, false)
			return

		&"recovery":
			_process_recovery(delta)
			return

	if slam_timer >= slam_interval:
		_begin_slam()
		return

	if combo_timer <= 0.0:
		_begin_combo()
		return

	if charge_timer >= charge_interval and distance > stopping_distance * 1.5:
		_begin_charge()
		return

	_process_pursuit(delta)


func _process(delta: float) -> void:
	if current_state == &"slam_windup":
		_animate_slam_warning(delta)

	if impact_active:
		_animate_impact(delta)


func _find_player() -> void:
	if player_node_path != NodePath():
		player = get_node_or_null(player_node_path) as Node3D

	if player == null:
		var scene := get_tree().current_scene
		if scene != null:
			player = scene.get_node_or_null("Player") as Node3D

	if player == null:
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			player = players[0] as Node3D


# ============================================================
# STANDALONE MOVEMENT AI
# ============================================================

func _process_pursuit(delta: float) -> void:
	var to_player := player.global_position - global_position
	to_player.y = 0.0

	var distance := to_player.length()
	if distance < 0.001:
		return

	var forward := to_player.normalized()
	_face_direction(forward, delta)

	var desired_velocity := Vector3.ZERO

	if distance > stopping_distance:
		desired_velocity += forward * move_speed

	var sideways := Vector3(-forward.z, 0.0, forward.x)
	desired_velocity += sideways * strafe_speed * strafe_direction

	velocity.x = move_toward(
		velocity.x,
		desired_velocity.x,
		acceleration * delta
	)
	velocity.z = move_toward(
		velocity.z,
		desired_velocity.z,
		acceleration * delta
	)

	_apply_gravity(delta)
	move_and_slide()

	if Vector2(velocity.x, velocity.z).length() > 0.25:
		_play_animation(walk_animation)
	else:
		_play_animation(idle_animation)


func _face_player(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	var direction := player.global_position - global_position
	direction.y = 0.0

	if direction.length_squared() > 0.001:
		_face_direction(direction.normalized(), delta)


func _face_direction(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.001:
		return

	var target_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(delta * 9.0, 1.0))


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0


func _stop_horizontal_movement(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
	_apply_gravity(delta)
	move_and_slide()


func _distance_to_player() -> float:
	if player == null or not is_instance_valid(player):
		return INF

	var offset := player.global_position - global_position
	offset.y = 0.0
	return offset.length()


# ============================================================
# DASH / CHARGE ATTACK
# ============================================================

func _begin_charge() -> void:
	current_state = &"charge_windup"
	state_timer = charge_windup
	attack_has_hit = false

	velocity.x = 0.0
	velocity.z = 0.0

	_face_player(0.15)
	attack_direction = _get_predicted_direction()
	_play_animation(attack_animation)


func _process_charge_windup(delta: float) -> void:
	state_timer -= delta
	_stop_horizontal_movement(delta)
	_face_player(delta)

	if state_timer <= 0.0:
		dash_direction = _get_predicted_direction()
		current_state = &"charging"
		state_timer = charge_duration
		charge_timer = 0.0
		attack_has_hit = false


func _process_charging(delta: float) -> void:
	state_timer -= delta

	velocity.x = dash_direction.x * charge_speed
	velocity.z = dash_direction.z * charge_speed
	_apply_gravity(delta)
	move_and_slide()

	if not attack_has_hit and player != null and is_instance_valid(player):
		var offset := player.global_position - global_position
		offset.y = 0.0

		var forward_distance := offset.dot(dash_direction)
		var side_distance := absf(
			dash_direction.x * offset.z - dash_direction.z * offset.x
		)

		if (
			forward_distance >= 0.0
			and forward_distance <= charge_speed * delta + 2.0
			and side_distance <= charge_width
		):
			_damage_player(charge_damage)
			attack_has_hit = true

	if state_timer <= 0.0 or is_on_wall():
		velocity.x = 0.0
		velocity.z = 0.0
		_begin_recovery(0.65)


# ============================================================
# GROUND SLAM
# ============================================================

func _begin_slam() -> void:
	current_state = &"slam_windup"
	state_timer = slam_windup
	slam_visual_time = 0.0
	slam_start_position = global_position

	slam_target = player.global_position
	slam_target.y = global_position.y

	slam_progress = 0.0
	velocity.x = 0.0
	velocity.z = 0.0

	_place_slam_warning()
	_play_animation(attack_animation)


func _process_slam_windup(delta: float) -> void:
	state_timer -= delta
	_stop_horizontal_movement(delta)

	if state_timer <= 0.0:
		current_state = &"slam_airborne"
		slam_progress = 0.0
		_hide_slam_warning()


func _process_slam_airborne(delta: float) -> void:
	slam_progress += delta / maxf(0.65, 0.001)
	var t := clampf(slam_progress, 0.0, 1.0)

	var landing := slam_start_position.lerp(slam_target, t)
	landing.y += sin(t * PI) * slam_jump_height
	global_position = landing

	velocity = Vector3.ZERO

	if t >= 1.0:
		global_position = slam_target
		_execute_slam()
		slam_timer = 0.0
		_begin_recovery(0.75)


func _execute_slam() -> void:
	_hide_slam_warning()
	_start_impact_effect()

	if player == null or not is_instance_valid(player):
		return

	var offset := player.global_position - slam_target
	offset.y = 0.0

	if offset.length() <= slam_radius:
		_damage_player(slam_damage)


func _place_slam_warning() -> void:
	var floor_position := Vector3(
		slam_target.x,
		VISUAL_FLOOR_Y,
		slam_target.z
	)

	slam_marker.global_position = floor_position
	slam_marker.scale = Vector3(slam_radius, 1.0, slam_radius)
	slam_marker.visible = true

	slam_outer_ring.global_position = floor_position
	slam_inner_ring.global_position = floor_position
	slam_outer_ring.scale = Vector3(slam_radius, 1.0, slam_radius)
	slam_inner_ring.scale = Vector3(slam_radius, 1.0, slam_radius)

	slam_outer_ring.visible = true
	slam_inner_ring.visible = true


func _hide_slam_warning() -> void:
	if is_instance_valid(slam_marker):
		slam_marker.visible = false
	if is_instance_valid(slam_outer_ring):
		slam_outer_ring.visible = false
	if is_instance_valid(slam_inner_ring):
		slam_inner_ring.visible = false


func _animate_slam_warning(delta: float) -> void:
	slam_visual_time += delta

	var remaining := clampf(
		state_timer / maxf(slam_windup, 0.001),
		0.0,
		1.0
	)

	var pulse := 1.0 + sin(
		slam_visual_time * lerpf(4.0, 13.0, 1.0 - remaining)
	) * 0.07

	slam_outer_ring.scale = Vector3(
		slam_radius * pulse,
		1.0,
		slam_radius * pulse
	)

	slam_inner_ring.scale = Vector3(
		slam_radius * (2.0 - pulse),
		1.0,
		slam_radius * (2.0 - pulse)
	)

	if remaining < 0.35:
		slam_marker_material.albedo_color = Color(1.0, 0.08, 0.02, 0.4)
	else:
		slam_marker_material.albedo_color = Color(0.05, 0.65, 1.0, 0.2)


# ============================================================
# TWO-SLASH CLEAVE COMBO
# ============================================================

func _begin_combo() -> void:
	current_state = &"combo_cone_warning"
	state_timer = combo_telegraph_duration
	attack_has_hit = false

	velocity.x = 0.0
	velocity.z = 0.0

	attack_direction = _get_predicted_direction()
	_update_combo_telegraph(true)
	_play_animation(attack_animation)


func _process_combo_warning(delta: float, is_cone: bool) -> void:
	state_timer -= delta
	_stop_horizontal_movement(delta)

	attack_direction = _get_predicted_direction()
	_update_combo_telegraph(is_cone)

	if state_timer <= 0.0:
		attack_direction = _get_predicted_direction()
		_hide_combo_telegraphs()
		_resolve_combo_hit(is_cone)

		if is_cone:
			current_state = &"combo_cone_attack"
		else:
			current_state = &"combo_line_attack"

		state_timer = combo_slash_duration
		_play_animation(attack_animation)


func _process_combo_attack(delta: float, is_cone: bool) -> void:
	state_timer -= delta
	_stop_horizontal_movement(delta)

	if state_timer <= 0.0:
		if is_cone:
			current_state = &"combo_pause"
			state_timer = combo_between_slashes
		else:
			combo_timer = randf_range(
				combo_min_interval,
				combo_max_interval
			)
			_begin_recovery(0.6)


func _process_combo_pause(delta: float) -> void:
	state_timer -= delta
	_stop_horizontal_movement(delta)

	if state_timer <= 0.0:
		current_state = &"combo_line_warning"
		state_timer = combo_telegraph_duration
		attack_direction = _get_predicted_direction()
		_update_combo_telegraph(false)


func _update_combo_telegraph(is_cone: bool) -> void:
	var angle := atan2(-attack_direction.x, -attack_direction.z)

	var floor_position := Vector3(
		global_position.x,
		VISUAL_FLOOR_Y,
		global_position.z
	)

	if is_cone:
		cone_mesh.global_position = floor_position
		cone_mesh.rotation.y = angle
		cone_mesh.visible = true
		line_mesh.visible = false
	else:
		# The line mesh is centered along its length.
		# Offset it forward by half its length so it begins at the boss
		# and extends outward only in the attack direction.
		line_mesh.global_position = (
			floor_position
			+ attack_direction * (combo_line_range * 0.5)
		)
		line_mesh.rotation.y = angle
		line_mesh.visible = true
		cone_mesh.visible = false


func _hide_combo_telegraphs() -> void:
	if is_instance_valid(cone_mesh):
		cone_mesh.visible = false
	if is_instance_valid(line_mesh):
		line_mesh.visible = false


func _resolve_combo_hit(is_cone: bool) -> void:
	if player == null or not is_instance_valid(player):
		return

	var offset := player.global_position - global_position
	offset.y = 0.0

	var distance := offset.length()
	if distance < 0.001:
		_damage_player(combo_damage)
		return

	var direction := offset.normalized()
	var dot := attack_direction.dot(direction)

	if is_cone:
		var minimum_dot := cos(deg_to_rad(combo_cone_half_angle))

		if distance <= combo_cone_range and dot >= minimum_dot:
			_damage_player(combo_damage)
	else:
		var perpendicular_distance := absf(
			attack_direction.x * offset.z
			- attack_direction.z * offset.x
		)

		if (
			distance <= combo_line_range
			and dot > 0.0
			and perpendicular_distance <= combo_line_width * 0.5
		):
			_damage_player(combo_damage)


# ============================================================
# PREDICTION AND ATTACK RECOVERY
# ============================================================

func _get_predicted_direction() -> Vector3:
	if player == null or not is_instance_valid(player):
		return attack_direction

	var predicted_position := player.global_position

	if player is CharacterBody3D:
		var player_body := player as CharacterBody3D
		var predicted_velocity := player_body.velocity
		predicted_velocity.y = 0.0

		var prediction := predicted_velocity * combo_prediction_time

		if prediction.length() > combo_max_prediction_distance:
			prediction = (
				prediction.normalized()
				* combo_max_prediction_distance
			)

		predicted_position += prediction

	var direction := predicted_position - global_position
	direction.y = 0.0

	if direction.length_squared() > 0.001:
		return direction.normalized()

	return attack_direction


func _begin_recovery(duration: float) -> void:
	current_state = &"recovery"
	state_timer = duration
	velocity.x = 0.0
	velocity.z = 0.0
	_play_animation(idle_animation)


func _process_recovery(delta: float) -> void:
	state_timer -= delta
	_stop_horizontal_movement(delta)

	if state_timer <= 0.0:
		current_state = &"pursue"


# ============================================================
# DAMAGE AND DEATH
# ============================================================

func take_projectile_hit(amount: int, critical: bool) -> void:
	_apply_damage(amount, critical)


func take_damage(amount: int) -> void:
	_apply_damage(amount, false)


func _apply_damage(amount: int, critical: bool) -> void:
	if dead:
		return

	var actual_damage: int = maxi(amount, 0)

	health = maxi(health - actual_damage, 0)

	# Create floating combat text.
	var damage_number = DAMAGE_NUMBER_SCENE.instantiate()

	get_tree().current_scene.add_child(damage_number)

	damage_number.global_position = global_position + Vector3(0.0, 2.0, 0.0)
	damage_number.setup(actual_damage, critical)

	print(
		"BOSS HIT! Damage: ", actual_damage,
		" | Critical: ", critical,
		" | HP remaining: ", health, "/", boss_max_health
	)

	if health <= 0:
		_die()


func _die() -> void:
	dead = true
	boss_defeated.emit()
	current_state = &"dead"
	velocity = Vector3.ZERO

	_hide_slam_warning()
	_hide_combo_telegraphs()

	if is_instance_valid(impact_ring):
		impact_ring.visible = false

	_play_animation(death_animation)

	if (
		sprite != null
		and sprite.sprite_frames != null
		and sprite.sprite_frames.has_animation(death_animation)
	):
		await sprite.animation_finished

	queue_free()


func _damage_player(amount: int) -> void:
	if player == null or not is_instance_valid(player):
		return

	if player.has_method("take_damage"):
		player.call("take_damage", amount)


func _play_animation(animation_name: StringName) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	if not sprite.sprite_frames.has_animation(animation_name):
		return

	if sprite.animation != animation_name or not sprite.is_playing():
		sprite.play(animation_name)


# ============================================================
# SLAM VISUAL CREATION
# ============================================================

func create_slam_visuals() -> void:
	slam_marker = MeshInstance3D.new()
	slam_marker.name = "GroundSlamWarning"

	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.025
	disc.radial_segments = 48

	slam_marker.mesh = disc
	slam_marker.scale = Vector3(slam_radius, 1.0, slam_radius)

	slam_marker_material = StandardMaterial3D.new()
	slam_marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	slam_marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	slam_marker_material.albedo_color = Color(0.05, 0.65, 1.0, 0.2)
	slam_marker_material.emission_enabled = true
	slam_marker_material.emission = Color(0.0, 0.45, 1.0)
	slam_marker_material.emission_energy_multiplier = 1.5

	slam_marker.material_override = slam_marker_material
	slam_marker.visible = false
	get_tree().current_scene.add_child(slam_marker)

	slam_outer_ring = _create_warning_ring(
		"GroundSlamOuterRing",
		Color(0.0, 0.65, 1.0, 1.0)
	)

	slam_inner_ring = _create_warning_ring(
		"GroundSlamInnerRing",
		Color(0.2, 1.0, 1.0, 1.0)
	)


func _create_warning_ring(
	ring_name: String,
	ring_color: Color
) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	ring.name = ring_name

	var torus := TorusMesh.new()
	torus.inner_radius = 0.90
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 12

	ring.mesh = torus
	ring.rotation_degrees.x = 90.0
	ring.scale = Vector3(slam_radius, 1.0, slam_radius)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = ring_color
	material.emission_enabled = true
	material.emission = ring_color
	material.emission_energy_multiplier = 2.5

	ring.material_override = material
	ring.visible = false
	get_tree().current_scene.add_child(ring)

	return ring


# ============================================================
# IMPACT VISUAL
# ============================================================

func create_impact_visual() -> void:
	impact_ring = MeshInstance3D.new()
	impact_ring.name = "GroundSlamImpactRing"

	var torus := TorusMesh.new()
	torus.inner_radius = 0.90
	torus.outer_radius = 1.0
	torus.rings = 40
	torus.ring_segments = 12

	impact_ring.mesh = torus
	impact_ring.rotation_degrees.x = 90.0

	impact_material = StandardMaterial3D.new()
	impact_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	impact_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	impact_material.albedo_color = Color(0.1, 0.8, 1.0, 1.0)
	impact_material.emission_enabled = true
	impact_material.emission = Color(0.0, 0.6, 1.0)
	impact_material.emission_energy_multiplier = 4.0

	impact_ring.material_override = impact_material
	impact_ring.visible = false
	get_tree().current_scene.add_child(impact_ring)


func _start_impact_effect() -> void:
	impact_active = true
	impact_timer = 0.0

	impact_ring.global_position = Vector3(
		slam_target.x,
		VISUAL_FLOOR_Y,
		slam_target.z
	)

	impact_ring.scale = Vector3(0.1, 1.0, 0.1)
	impact_ring.visible = true


func _animate_impact(delta: float) -> void:
	impact_timer += delta

	var progress := clampf(
		impact_timer / maxf(impact_duration, 0.001),
		0.0,
		1.0
	)

	var radius := lerpf(0.1, impact_max_radius, progress)
	impact_ring.scale = Vector3(radius, 1.0, radius)

	impact_material.albedo_color = Color(
		0.1,
		0.8,
		1.0,
		1.0 - progress
	)

	if progress >= 1.0:
		impact_active = false
		impact_ring.visible = false


# ============================================================
# COMBO TELEGRAPH CREATION
# ============================================================

func create_combo_telegraphs() -> void:
	cone_mesh = MeshInstance3D.new()
	cone_mesh.name = "BossConeTelegraph"

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)

	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()

	vertices.append(Vector3.ZERO)

	var segments := 48

	for i in range(segments + 1):
		var angle := deg_to_rad(
			-combo_cone_half_angle
			+ 2.0 * combo_cone_half_angle
			* float(i) / float(segments)
		)

		vertices.append(Vector3(
			sin(angle) * combo_cone_range,
			0.0,
			-cos(angle) * combo_cone_range
		))

	for i in range(segments):
		indices.append(0)
		indices.append(i + 1)
		indices.append(i + 2)

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices

	var cone_array := ArrayMesh.new()
	cone_array.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES,
		arrays
	)

	cone_mesh.mesh = cone_array

	var cone_material := StandardMaterial3D.new()
	cone_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cone_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cone_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cone_material.albedo_color = Color(1.0, 0.05, 0.02, 0.35)
	cone_material.emission_enabled = true
	cone_material.emission = Color(1.0, 0.02, 0.01)
	cone_material.emission_energy_multiplier = 1.5

	cone_mesh.material_override = cone_material
	cone_mesh.visible = false
	get_tree().current_scene.add_child(cone_mesh)

	line_mesh = MeshInstance3D.new()
	line_mesh.name = "BossLinearTelegraph"

	var line_box := BoxMesh.new()
	line_box.size = Vector3(
		combo_line_width,
		0.025,
		combo_line_range
	)

	line_mesh.mesh = line_box

	var line_material := StandardMaterial3D.new()
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_material.albedo_color = Color(1.0, 0.03, 0.01, 0.45)
	line_material.emission_enabled = true
	line_material.emission = Color(1.0, 0.01, 0.01)
	line_material.emission_energy_multiplier = 2.0

	line_mesh.material_override = line_material
	line_mesh.visible = false
	get_tree().current_scene.add_child(line_mesh)
