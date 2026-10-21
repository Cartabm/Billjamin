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

	_health_multiplier = 1.0 + float(extra_rooms) * health_increase_per_room
	_damage_multiplier = 1.0 + float(extra_rooms) * damage_increase_per_room

	kills_required = maxi(
		1,
		roundi(float(kills_required) * (
			1.0 + float(extra_rooms) * enemy_count_increase_per_room
		))
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

	for enemy in _living_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and not enemy.is_dying:
			enemy._horde_step(delta)

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
	var scene: PackedScene = enemy_scenes.pick_random()
	var enemy := scene.instantiate() as CharacterBody3D

	if enemy == null:
		push_error("RoomEncounter: Enemy scene root must be CharacterBody3D.")
		_spawned_count = kills_required
		return

	var center := get_parent() as Node3D

	var spawn_offset := Vector3(
		randf_range(-6.0, 6.0),
		enemy_spawn_height,
		randf_range(-6.0, 6.0)
	)

	# Apply room scaling before enemy._ready().
	if _has_property(enemy, "max_health"):
		enemy.set(
			"max_health",
			maxi(1, roundi(float(enemy.get("max_health")) * _health_multiplier))
		)

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
			enemy.set(
				property_name,
				maxi(
					1,
					roundi(float(enemy.get(property_name)) * _damage_multiplier)
				)
			)

	get_tree().current_scene.add_child(enemy)

	enemy.global_position = center.global_position + spawn_offset
	enemy.dungeon_enemy_killed.connect(_on_enemy_killed)

	_living_enemies.append(enemy)
	_spawned_count += 1


func _has_property(object: Object, property_name: String) -> bool:
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
	progress_changed.emit(kills_completed, kills_required)

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
