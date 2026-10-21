
extends Node3D

@export_group("Enemy Spawn Toggles")
@export var spawn_regular_enemies: bool = true
@export var spawn_chargers: bool = true
@export var spawn_stalkers: bool = true
@export var spawn_brutes: bool = true
@export var spawn_ranged: bool = true

@export_group("Scene Mode")
@export var overworld_mode: bool = false
@export var debug_spawning: bool = true
@export var max_living_enemies: int = 100

@export_group("Spawn Settings")
@export var spawn_interval: float = 1.5
@export var horde_size: int = 4
@export var horde_size_increase: int = 1
@export var horde_increase_interval: float = 60.0

@export var min_spawn_distance: float = 10.0
@export var max_spawn_distance: float = 50.0
@export var spawn_attempts: int = 60
@export var enemy_spawn_height: float = 0.75

@export_group("Ground Detection")
@export_flags_3d_physics var ground_collision_mask: int = 4
@export var ground_ray_start_height: float = 50.0
@export var ground_ray_length: float = 150.0
@export_flags_3d_physics var fallback_ground_mask: int = 1

@export_group("Enemy Teleporting")
@export var enable_predictive_teleporting: bool = true
@export var teleport_check_interval: float = 0.5
@export var teleport_forward_angle: float = 70.0
@export var teleport_min_distance: float = 12.0
@export var teleport_max_distance: float = 45.0

@export_group("Enemy Scenes")
@export var enemy_scene: PackedScene
@export var charger_scene: PackedScene
@export var stalker_scene: PackedScene
@export var brute_scene: PackedScene
@export var boss_scene: PackedScene
@export var ranged_scene: PackedScene

@export_group("Arena")
@export var arena_duration: float = 600

@export_group("Difficulty")
@export var difficulty_interval: float = 30.0
@export var spawn_interval_decrease: float = 0.25
@export var minimum_spawn_interval: float = 0.75

@export_group("Boss Jump")
@export var slam_jump_height: float = 3.0

var spawn_timer: float = 0.0
var difficulty_timer: float = 0.0
var horde_timer: float = 0.0
var teleport_timer: float = 0.0

var current_horde_size: int = 4
var player: CharacterBody3D

var slam_start_position: Vector3 = Vector3.ZERO
var slam_jump_progress: float = 0.0

var arena_time_remaining: float = 15.0
var boss_fight_started: bool = false

var arena_timer_label: Label

var last_player_position: Vector3 = Vector3.ZERO
var player_travel_direction: Vector3 = Vector3.ZERO


func _ready() -> void:
	# Automatically use open-world rules in the procedural test scene.
	if get_tree().current_scene != null and get_tree().current_scene.name == "OverworldTest":
		overworld_mode = true
	player = _find_player()
	current_horde_size = horde_size
	arena_time_remaining = arena_duration

	var scene_root := get_tree().current_scene

	if scene_root != null:
		arena_timer_label = scene_root.get_node_or_null(
			"CanvasLayer/ArenaTimerLabel"
		) as Label

	if player != null:
		last_player_position = player.global_position

	if not overworld_mode:
		update_arena_timer_label()
	if debug_spawning:
		print("SPAWNER ready | overworld=", overworld_mode, " | player=", player != null, " | ground mask=", ground_collision_mask)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = _find_player()

	if player == null:
		return

	_update_player_travel_direction(delta)

	if enable_predictive_teleporting and not boss_fight_started:
		teleport_timer += delta

		if teleport_timer >= teleport_check_interval:
			teleport_timer = 0.0
			_check_distant_enemies()

	if boss_fight_started:
		return

	if not overworld_mode:
		arena_time_remaining -= delta
		if arena_time_remaining <= 0.0:
			arena_time_remaining = 0.0
			update_arena_timer_label()
			start_boss_fight()
			return
		update_arena_timer_label()

	difficulty_timer += delta
	horde_timer += delta

	if difficulty_timer >= difficulty_interval:
		difficulty_timer = 0.0
		spawn_interval = maxf(
			minimum_spawn_interval,
			spawn_interval - spawn_interval_decrease
		)

	if horde_timer >= horde_increase_interval:
		horde_timer = 0.0
		current_horde_size += horde_size_increase

	spawn_timer += delta

	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		spawn_horde()


func _find_player() -> CharacterBody3D:
	var scene_root := get_tree().current_scene

	if scene_root != null:
		for player_name in ["TestPlayer", "Player"]:
			var found_player := scene_root.get_node_or_null(player_name) as CharacterBody3D
			if found_player != null:
				return found_player

	var players := get_tree().get_nodes_in_group("player")

	for node in players:
		if node is CharacterBody3D:
			return node as CharacterBody3D

	return null


func _update_player_travel_direction(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	var direction := Vector3.ZERO

	direction.x = player.global_position.x - last_player_position.x
	direction.z = player.global_position.z - last_player_position.z

	# Prefer actual displacement so this works with keyboard movement,
	# dashes, knockbacks, and other movement systems.
	if direction.length_squared() > 0.0025:
		player_travel_direction = direction.normalized()
	elif player.velocity.x * player.velocity.x + player.velocity.z * player.velocity.z > 0.25:
		player_travel_direction = Vector3(
			player.velocity.x,
			0.0,
			player.velocity.z
		).normalized()

	last_player_position = player.global_position


func update_arena_timer_label() -> void:
	if arena_timer_label == null:
		return

	var total_seconds := ceili(arena_time_remaining)
	var minutes := int(total_seconds / 60.0)
	var seconds := total_seconds % 60

	if boss_fight_started:
		arena_timer_label.text = "BOSS FIGHT"
	else:
		arena_timer_label.text = "%02d:%02d" % [
			minutes,
			seconds
		]


func start_boss_fight() -> void:
	if boss_fight_started:
		return

	boss_fight_started = true
	print("Arena time elapsed. Starting boss fight.")

	for enemy in get_tree().get_nodes_in_group("normal_enemy"):
		if is_instance_valid(enemy):
			enemy.queue_free()

	var scene_root := get_tree().current_scene

	if scene_root == null:
		return

	# Also remove a regular Enemy directly placed in the arena scene.
	for child in scene_root.get_children():
		if child is CharacterBody3D:
			var enemy_script = child.get_script()

			if enemy_script != null:
				if enemy_script.resource_path.to_lower() == "res://Scripts/enemy.gd":
					child.queue_free()

	update_arena_timer_label()

	if boss_scene == null:
		push_error(
			"Boss Scene is not assigned on EnemySpawner. "
			+ "Assign Boss.tscn in the Inspector."
		)
		return

	var boss = boss_scene.instantiate()

	if boss.get("arena_half_size") != null:
		boss.set(
			"arena_half_size",
			maxf(1.0, get_arena_size() / 2.0 - 1.0)
		)

	scene_root.add_child(boss)
	boss.global_position = Vector3(0.0, 0.75, 0.0)



func spawn_horde() -> void:
	var living := get_tree().get_nodes_in_group("normal_enemy").size()
	var amount := mini(current_horde_size, maxi(max_living_enemies - living, 0))
	for i in range(amount):
		if boss_fight_started:
			return

		spawn_enemy()


func get_arena_size() -> float:
	var scene_root := get_tree().current_scene

	if scene_root != null:
		var configured_size = scene_root.get("arena_size")

		if configured_size != null:
			return float(configured_size)

	return 20.0


func spawn_enemy() -> void:
	if boss_fight_started or player == null:
		return

	var available_scenes: Array[PackedScene] = []

	if spawn_regular_enemies and enemy_scene != null:
		available_scenes.append(enemy_scene)

	if spawn_chargers and charger_scene != null:
		available_scenes.append(charger_scene)

	if spawn_stalkers and stalker_scene != null:
		available_scenes.append(stalker_scene)

	if spawn_brutes and brute_scene != null:
		available_scenes.append(brute_scene)

	if spawn_ranged and ranged_scene != null:
		available_scenes.append(ranged_scene)

	if available_scenes.is_empty():
		if debug_spawning:
			push_warning("SPAWNER: No enemy PackedScenes assigned/enabled in Inspector")
		return

	var spawn_position := Vector3.ZERO
	var found_position := false

	for attempt in range(spawn_attempts):
		var candidate := _get_random_position_near_player()

		if candidate == Vector3.INF:
			continue

		var ground_position := _find_ground_position(candidate)

		if ground_position == Vector3.INF:
			continue

		var distance := _horizontal_distance(
			ground_position,
			player.global_position
		)

		if distance < min_spawn_distance or distance > max_spawn_distance:
			continue

		spawn_position = ground_position + Vector3.UP * enemy_spawn_height
		found_position = true
		break

	if not found_position:
		if debug_spawning:
			push_warning("SPAWNER: No terrain ray hit after %d attempts. Check terrain collision layer and ground masks (%d / %d)." % [spawn_attempts, ground_collision_mask, fallback_ground_mask])
		return

	var chosen_scene: PackedScene = available_scenes.pick_random()
	var enemy = chosen_scene.instantiate()

	if not overworld_mode and enemy.get("arena_half_size") != null:
		enemy.set(
			"arena_half_size",
			maxf(1.0, get_arena_size() / 2.0 - 1.0)
		)

	enemy.add_to_group("normal_enemy")

	var scene_root := get_tree().current_scene

	if scene_root == null:
		enemy.free()
		return

	# Set local transform before _ready() registers the enemy with HordeManager.
	# Spawned enemies are direct children of scene_root.
	enemy.position = scene_root.to_local(spawn_position) if scene_root is Node3D else spawn_position
	scene_root.add_child(enemy)
	if debug_spawning:
		print("SPAWNER created: ", enemy.name, " at ", enemy.global_position)


func _get_random_position_near_player() -> Vector3:
	var angle := randf_range(0.0, TAU)
	var distance := randf_range(
		min_spawn_distance,
		max_spawn_distance
	)

	return Vector3(
		player.global_position.x + cos(angle) * distance,
		player.global_position.y,
		player.global_position.z + sin(angle) * distance
	)


func _find_ground_position(candidate: Vector3) -> Vector3:
	var world := get_world_3d()

	if world == null:
		return Vector3.INF

	var ray_origin := Vector3(
		candidate.x,
		candidate.y + ground_ray_start_height,
		candidate.z
	)

	var ray_end := Vector3(
		candidate.x,
		ray_origin.y - ground_ray_length,
		candidate.z
	)

	var query := PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_end,
		ground_collision_mask
	)

	query.collide_with_areas = false
	query.collide_with_bodies = true

	# Don't let the player or existing enemies count as the ground.
	var excluded: Array[RID] = []

	if player is CollisionObject3D:
		excluded.append(player.get_rid())

	# Regular enemies are on collision layer 2, so the ground-only
	# ray mask does not need to exclude each enemy individually.

	query.exclude = excluded

	var result := world.direct_space_state.intersect_ray(query)

	if result.is_empty() and fallback_ground_mask != 0 and fallback_ground_mask != ground_collision_mask:
		query.collision_mask = fallback_ground_mask
		result = world.direct_space_state.intersect_ray(query)
	if result.is_empty():
		return Vector3.INF
	# Avoid walls and other steep surfaces being treated as terrain.
	if (result["normal"] as Vector3).y < 0.55:
		return Vector3.INF
	return result["position"] as Vector3


func _check_distant_enemies() -> void:
	if player == null or not is_instance_valid(player):
		return

	for enemy in get_tree().get_nodes_in_group("normal_enemy"):
		if not is_instance_valid(enemy):
			continue

		if not enemy is Node3D:
			continue

		var enemy_node := enemy as Node3D

		var distance := _horizontal_distance(
			enemy_node.global_position,
			player.global_position
		)

		if distance > max_spawn_distance:
			_teleport_enemy_ahead(enemy_node)


func _teleport_enemy_ahead(enemy: Node3D) -> void:
	if player == null or not is_instance_valid(player):
		return

	var forward := player_travel_direction

	if forward.length_squared() < 0.001:
		# If the player is stationary, choose a random direction.
		var random_angle := randf_range(0.0, TAU)
		forward = Vector3(
			cos(random_angle),
			0.0,
			sin(random_angle)
		)

	var base_angle := atan2(forward.x, forward.z)
	var max_angle := deg_to_rad(teleport_forward_angle)

	for attempt in range(spawn_attempts):
		var angle := base_angle + randf_range(-max_angle, max_angle)
		var distance := randf_range(
			teleport_min_distance,
			minf(teleport_max_distance, max_spawn_distance - 1.0)
		)

		var candidate := Vector3(
			player.global_position.x + sin(angle) * distance,
			player.global_position.y,
			player.global_position.z + cos(angle) * distance
		)

		var ground_position := _find_ground_position(candidate)

		if ground_position == Vector3.INF:
			continue

		var player_distance := _horizontal_distance(
			ground_position,
			player.global_position
		)

		if (
			player_distance < min_spawn_distance
			or player_distance > max_spawn_distance
		):
			continue

		enemy.global_position = (
			ground_position + Vector3.UP * enemy_spawn_height
		)

		if enemy is CharacterBody3D:
			var body := enemy as CharacterBody3D
			body.velocity = Vector3.ZERO

		return


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
