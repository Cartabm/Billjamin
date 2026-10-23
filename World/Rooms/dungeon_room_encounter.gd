
extends Node3D

signal encounter_started
signal encounter_completed
signal progress_changed(kills: int, required: int)

@export var kills_required: int = 30
@export var max_alive: int = 12
@export var spawn_interval: float = 0.8

@export_group("Spawn Pacing")
@export var initial_spawn_count: int = 6
@export var enemies_per_spawn_tick: int = 2

@export var enemy_spawn_height: float = 0.75
@export var enemy_scenes: Array[PackedScene] = []

# Centralized balance settings.
var enemy_spawn_weights: Array[int] = []

var configured_elite_chance: float = 0.08
var configured_health_multiplier: float = 1.0
var configured_damage_multiplier: float = 1.0
var configured_speed_multiplier: float = 1.0

var configured_currency_drop_chance: float = 0.25
var configured_currency_min_drop: int = 5
var configured_currency_max_drop: int = 15

var configured_elite_currency_drop_chance: float = 0.75
var configured_elite_currency_min_drop: int = 15
var configured_elite_currency_max_drop: int = 35


@export_group("Room Difficulty Scaling")
@export var health_increase_per_room: float = 0.15
@export var damage_increase_per_room: float = 0.0575
@export var enemy_count_increase_per_room: float = 0.10
@export var extra_alive_every_rooms: int = 3
@export var spawn_speed_increase_per_room: float = 0.05
@export var minimum_spawn_interval: float = 0.15

var kills_completed: int = 0
var encounter_active: bool = false
var encounter_cleared: bool = false
var door_gates: Array[Node3D] = []

var _spawned_count: int = 0
var _spawn_timer: float = 0.0
var _living_enemies: Array[CharacterBody3D] = []

var room_difficulty: int = 1
var _difficulty_applied: bool = false
var _health_multiplier: float = 1.0
var _damage_multiplier: float = 1.0


func register_door(gate: Node3D) -> void:
	door_gates.append(gate)


func set_room_difficulty(level: int) -> void:
	if _difficulty_applied:
		return

	room_difficulty = maxi(level, 1)
	var extra_rooms: int = room_difficulty - 1

	_health_multiplier = (
		1.0 + float(extra_rooms) * health_increase_per_room
	)

	_damage_multiplier = (
		1.0 + float(extra_rooms) * damage_increase_per_room
	)

	kills_required = maxi(
		1,
		roundi(
			float(kills_required) * (
				1.0 + float(extra_rooms) * enemy_count_increase_per_room
			)
		)
	)

	if extra_alive_every_rooms > 0:
		max_alive += extra_rooms / extra_alive_every_rooms

	spawn_interval = maxf(
		minimum_spawn_interval,
		spawn_interval / (
			1.0 + float(extra_rooms) * spawn_speed_increase_per_room
		)
	)

	_difficulty_applied = true


func start_encounter() -> void:
	if encounter_active or encounter_cleared:
		return

	if enemy_scenes.is_empty():
		push_warning("RoomEncounter: Assign at least one enemy scene.")
		return

	encounter_active = true
	kills_completed = 0
	_spawned_count = 0
	_spawn_timer = 0.0
	_living_enemies.clear()

	for gate in door_gates:
		if is_instance_valid(gate):
			gate.close_gate()

	progress_changed.emit(kills_completed, kills_required)
	encounter_started.emit()

	_spawn_enemies(initial_spawn_count)
	_spawn_timer = spawn_interval


func _physics_process(delta: float) -> void:
	if not encounter_active:
		return

	_spawn_timer -= delta

	if _spawn_timer <= 0.0:
		_spawn_enemies(enemies_per_spawn_tick)
		_spawn_timer = spawn_interval


func _spawn_enemies(amount: int) -> void:
	_living_enemies = _living_enemies.filter(
		func(e: CharacterBody3D) -> bool:
			return is_instance_valid(e) \
				and not e.is_queued_for_deletion() \
				and not e.is_dying
	)

	var available_slots: int = maxi(
		0,
		max_alive - _living_enemies.size()
	)

	var remaining_enemies: int = maxi(
		0,
		kills_required - _spawned_count
	)

	var spawn_amount: int = mini(
		maxi(amount, 0),
		mini(available_slots, remaining_enemies)
	)

	for i in range(spawn_amount):
		_spawn_one()


func _spawn_one() -> void:
	# Select enemy using configured spawn weights.
	var scene: PackedScene = _pick_enemy_scene()

	if scene == null:
		return

	var enemy := scene.instantiate() as CharacterBody3D

	if enemy == null:
		push_error(
			"RoomEncounter: Enemy scene root must be CharacterBody3D."
		)
		_spawned_count = kills_required
		return

	var center := get_parent() as Node3D

	var spawn_offset := Vector3(
		randf_range(-6.0, 6.0),
		enemy_spawn_height,
		randf_range(-6.0, 6.0)
	)

	# All enemy settings must be applied before add_child(),
	# because add_child() triggers the enemy's _ready() function.

	# Configure elite spawn chance.
	if _has_property(enemy, "elite_chance"):
		enemy.set(
			"elite_chance",
			configured_elite_chance
		)

	# Apply base health multiplier AND room difficulty scaling.
	if _has_property(enemy, "max_health"):
		var original_health: float = float(
			enemy.get("max_health")
		)

		var scaled_health: int = maxi(
			1,
			roundi(
				original_health
				* configured_health_multiplier
				* _health_multiplier
			)
		)

		enemy.set("max_health", scaled_health)

	# Configure normal and elite currency rewards.
	var currency_settings: Dictionary = {
		"currency_drop_chance": configured_currency_drop_chance,
		"currency_min_drop": configured_currency_min_drop,
		"currency_max_drop": configured_currency_max_drop,
		"elite_currency_drop_chance": configured_elite_currency_drop_chance,
		"elite_currency_min_drop": configured_elite_currency_min_drop,
		"elite_currency_max_drop": configured_elite_currency_max_drop
	}

	for property_name in currency_settings:
		if _has_property(enemy, property_name):
			enemy.set(
				property_name,
				currency_settings[property_name]
			)

	# Apply base damage multiplier AND room difficulty scaling.
	var damage_properties: Array[String] = [
		"contact_damage",
		"charger_punch_damage",
		"stalker_attack_damage",
		"brute_attack_damage",
		"punch_damage",
		"attack_damage",
		"ranged_attack_damage"
	]

	for property_name in damage_properties:
		if _has_property(enemy, property_name):
			var original_damage: float = float(
				enemy.get(property_name)
			)

			var scaled_damage: int = maxi(
				1,
				roundi(
					original_damage
					* configured_damage_multiplier
					* _damage_multiplier
				)
			)

			enemy.set(property_name, scaled_damage)


	# Apply movement speed before the enemy enters the scene.
	if _has_property(enemy, "move_speed"):
		var original_speed: float = float(enemy.get("move_speed"))

		enemy.set(
			"move_speed",
			maxf(0.0, original_speed * configured_speed_multiplier)
		)

	# Add enemy to the active scene.
	get_tree().current_scene.add_child(enemy)

	enemy.global_position = (
		center.global_position + spawn_offset
	)

	# Connect dungeon kill tracking.
	enemy.dungeon_enemy_killed.connect(_on_enemy_killed)

	_living_enemies.append(enemy)
	_spawned_count += 1


func _has_property(
	object: Object,
	property_name: String
) -> bool:
	for property in object.get_property_list():
		if property["name"] == property_name:
			return true

	return false


func _on_enemy_killed(enemy: CharacterBody3D) -> void:
	if not encounter_active or not _living_enemies.has(enemy):
		return

	_living_enemies.erase(enemy)
	register_kill()


func register_kill() -> void:
	if not encounter_active:
		return

	kills_completed += 1

	progress_changed.emit(
		kills_completed,
		kills_required
	)

	if kills_completed >= kills_required:
		complete_encounter()


func complete_encounter() -> void:
	if not encounter_active:
		return

	encounter_active = false
	encounter_cleared = true

	for gate in door_gates:
		if is_instance_valid(gate):
			gate.open_gate()

	encounter_completed.emit()


func _pick_enemy_scene() -> PackedScene:
	if enemy_scenes.is_empty():
		return null

	# Fall back to equal probabilities if weights are missing.
	if enemy_spawn_weights.size() != enemy_scenes.size():
		return enemy_scenes.pick_random()

	var total_weight: int = 0

	for weight in enemy_spawn_weights:
		total_weight += maxi(0, weight)

	if total_weight <= 0:
		return null

	var roll: int = randi_range(1, total_weight)

	for i in range(enemy_scenes.size()):
		roll -= maxi(0, enemy_spawn_weights[i])

		if roll <= 0:
			return enemy_scenes[i]

	return null
