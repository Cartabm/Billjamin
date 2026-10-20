
extends Node3D

signal encounter_started
signal encounter_completed
signal progress_changed(kills: int, required: int)

@export var kills_required: int = 30
@export var max_alive: int = 30
@export var spawn_interval: float = 0.8
@export var enemy_spawn_height: float = 0.75
@export var enemy_scenes: Array[PackedScene] = []

@export_group("Room Difficulty Scaling")
@export var health_increase_per_room: float = 0.4025
@export var damage_increase_per_room: float = 0.0575
@export var enemy_count_increase_per_room: float = 0.23
@export var extra_alive_every_rooms: int = 1
@export var spawn_speed_increase_per_room: float = 0.115

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
		0.15,
		spawn_interval / (
			1.0 + float(extra_rooms) * spawn_speed_increase_per_room
		)
	)

	_difficulty_applied = true


func start_encounter() -> void:
	if encounter_active or encounter_cleared:
		return

	if enemy_scenes.is_empty():
		push_warning(
			"RoomEncounter: Assign at least one enemy scene in DungeonGeneratorTest Inspector."
		)
		return

	encounter_active = true
	kills_completed = 0
	_spawned_count = 0
	_spawn_timer = 0.0
	_living_enemies.clear()

	for gate in door_gates:
		gate.close_gate()

	progress_changed.emit(kills_completed, kills_required)
	encounter_started.emit()
	_fill_slots()


func _physics_process(delta: float) -> void:
	if not encounter_active:
		return

	for enemy in _living_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and not enemy.is_dying:
			enemy._horde_step(delta)

	_spawn_timer -= delta

	if _spawn_timer <= 0.0:
		_fill_slots()
		_spawn_timer = spawn_interval


func _fill_slots() -> void:
	_living_enemies = _living_enemies.filter(
		func(e: CharacterBody3D) -> bool:
			return is_instance_valid(e) \
				and not e.is_queued_for_deletion() \
				and not e.is_dying
	)

	while encounter_active \
	and _living_enemies.size() < max_alive \
	and _spawned_count < kills_required:
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

	# Apply room scaling before entering the scene tree.
	if _difficulty_applied:
		if _has_property(enemy, "max_health"):
			enemy.max_health = maxi(
				1,
				roundi(float(enemy.max_health) * _health_multiplier)
			)

		if _has_property(enemy, "contact_damage"):
			enemy.contact_damage = maxi(
				1,
				roundi(float(enemy.contact_damage) * _damage_multiplier)
			)

		if _has_property(enemy, "punch_damage"):
			enemy.punch_damage = maxi(
				1,
				roundi(float(enemy.punch_damage) * _damage_multiplier)
			)

		if _has_property(enemy, "attack_damage"):
			enemy.attack_damage = maxi(
				1,
				roundi(float(enemy.attack_damage) * _damage_multiplier)
			)

		# Ranged enemy projectile damage scaling.
		if _has_property(enemy, "ranged_attack_damage"):
			enemy.ranged_attack_damage = maxi(
				1,
				roundi(
					float(enemy.ranged_attack_damage)
					* _damage_multiplier
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
	else:
		_spawn_timer = spawn_interval


func complete_encounter() -> void:
	if not encounter_active:
		return

	encounter_active = false
	encounter_cleared = true

	for gate in door_gates:
		gate.open_gate()

	encounter_completed.emit()
