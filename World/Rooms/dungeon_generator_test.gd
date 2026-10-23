extends Node3D

const ROOM_STRAIGHT = preload("res://World/Rooms/Room_Straight.tscn")
const ROOM_DEAD_END = preload("res://World/Rooms/Room_DeadEnd.tscn")
const ROOM_CORNER = preload("res://World/Rooms/Room_Corner.tscn")
const ROOM_JUNCTION = preload("res://World/Rooms/Room_Junction.tscn")
const ROOM_ENCOUNTER_SCRIPT = preload("res://World/Rooms/dungeon_room_encounter.gd")
const GATE_SCENE = preload("res://World/Rooms/DungeonGate.tscn")
const WALL_HEIGHT := 5.0
const MINE_FLOOR_MATERIAL = preload("res://World/Materials/MineFloor_01.tres")
const MINE_WALL_MATERIAL = preload("res://World/Materials/MineWall_01.tres")
@onready var minimap: Control = get_node_or_null("DungeonMinimap/MinimapRoot/MinimapDisplay")

@export_group("Dungeon Appearance")

@export var floor_materials: Array[StandardMaterial3D] = []
@export var wall_materials: Array[StandardMaterial3D] = []

const DIRECTIONS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const ROOM_RESIZER = preload("res://World/Rooms/dungeon_room_resizer.gd")
const CAVE_DETAIL = preload("res://World/Rooms/dungeon_cave_detail.gd")
const ROCK_FILL = preload("res://World/Rooms/dungeon_rock_fill.gd")
const FOG_OF_WAR_SCRIPT = preload("res://World/Rooms/dungeon_fog_of_war.gd")

@onready var dungeon_settings = $DungeonSettings

func get_room_size() -> float:
	return dungeon_settings.room_size

func get_grid_spacing() -> float:
	return dungeon_settings.room_size + dungeon_settings.corridor_length

@export_range(2, 40, 1) var room_count := 12
@export_group("Centralized Balance")
@export var balance_profile: EnemyBalanceProfile
@export_group("DungeonEnemies")
@export var dungeon_enemy_scenes: Array[PackedScene] = []
@export_group("Dungeon Boss")
@export var boss_scene: PackedScene
@export var boss_spawn_height: float = 0.75
@export_range(0.05, 1.0, 0.05) var south_wall_opacity: float = 0.35
@onready var generated_rooms: Node3D = $GeneratedRooms
@onready var generated_corridors: Node3D = $GeneratedCorridors
var rng := RandomNumberGenerator.new()
var fog_of_war
var connections: Dictionary = {}
var room_encounters: Dictionary = {}
var active_room: Vector2i = Vector2i.ZERO
var player: Node3D
var room_progress_bar: ProgressBar
var room_progress_label: Label
var rooms_entered: int = 0
var boss_room_cell: Vector2i = Vector2i.ZERO
var boss_room_created: bool = false
var boss_spawned: bool = false
var boss_instance: Node3D
var dungeon_floor: int = 1
var dungeon_portal: Node3D
var floor_label: Label
const PORTAL_SCRIPT = preload("res://Scripts/DungeonPortal.gd")

func _enter_tree() -> void:
	if not CharacterManager.has_selected_character():
		return

	var old_player := get_node_or_null("Player") as Node3D
	if old_player == null:
		push_error("Dungeon: Original Player node not found!")
		return

	var selected_scene: PackedScene = CharacterManager.get_selected_player_scene()
	if selected_scene == null:
		push_error("Dungeon: Selected character scene not found!")
		return

	var spawn_transform := old_player.transform

	remove_child(old_player)
	old_player.queue_free()

	var new_player := selected_scene.instantiate() as CharacterBody3D
	if new_player == null:
		push_error("Dungeon: Selected character must be a CharacterBody3D!")
		return

	new_player.name = "Player"
	add_child(new_player)
	new_player.transform = spawn_transform

func _ready() -> void:
	rng.randomize()
	generate_dungeon()

	player = get_node_or_null("Player") as Node3D
	if player == null:
		push_error("DungeonGeneratorTest: Player node not found!")
		return

	# Start at the center of the generated starting room (grid cell 0, 0).
	# Defer placement until the newly added room and gate nodes finish setup.
	player.set_physics_process(false)
	_place_player_at_start.call_deferred()
	_create_room_progress_hud()
	_create_floor_hud()


func _place_player_at_start() -> void:
	if not is_instance_valid(player):
		return

	var start_room := generated_rooms.get_node_or_null("Room_0_0") as Node3D
	if start_room == null:
		push_error("DungeonGeneratorTest: Starting room Room_0_0 not found!")
		player.set_physics_process(true)
		return

	# Place the player at the room's actual world center, not its old scene position.
	player.global_position = start_room.to_global(Vector3(0.0, 1.0, 0.0))
	if player is CharacterBody3D:
		player.velocity = Vector3.ZERO
		player.reset_physics_interpolation()
	player.set_physics_process(true)
	print("Dungeon player start: ", player.global_position)


func _physics_process(_delta: float) -> void:
	if player == null:
		return
			# Update minimap when the player enters a room.
	var spacing: float = get_grid_spacing()

	var player_cell := Vector2i(
		roundi(player.global_position.x / spacing),
		roundi(player.global_position.z / spacing)
	)

	if connections.has(player_cell):
		var room_center := Vector3(
			player_cell.x * spacing,
			0.0,
			player_cell.y * spacing
		)

		var detection_half_size: float = get_room_size() * 0.5 - 2.5

		if absf(player.global_position.x - room_center.x) < detection_half_size \
		and absf(player.global_position.z - room_center.z) < detection_half_size:
			fog_of_war.reveal_room(player_cell, connections)
			if minimap != null and minimap.current_room != player_cell:
				minimap.enter_room(player_cell)
	if boss_room_created and not boss_spawned and player_cell == boss_room_cell:
		var boss_center := Vector3(boss_room_cell.x * spacing, 0.0, boss_room_cell.y * spacing)
		var boss_half := get_room_size() * 0.5 - 2.5
		if absf(player.global_position.x - boss_center.x) < boss_half and absf(player.global_position.z - boss_center.z) < boss_half:
			_spawn_boss()
	# Trigger only when fully inside a room, not in its corridor or doorway.
	for cell in room_encounters.keys():
		if cell == Vector2i.ZERO:
			continue
		var center := Vector3(cell.x * get_grid_spacing(), 0.0, cell.y * get_grid_spacing())
		var detection_half_size: float = get_room_size() * 0.5 - 2.5
		if absf(player.global_position.x - center.x) < detection_half_size and absf(player.global_position.z - center.z) < detection_half_size:
			var encounter: Node3D = room_encounters[cell]
			if not encounter.encounter_cleared and not encounter.encounter_active:
				active_room = cell

				rooms_entered += 1
				encounter.set_room_difficulty((dungeon_floor - 1) * (room_count - 1) + rooms_entered)
				encounter.start_encounter()
			return



func generate_dungeon() -> void:
	if fog_of_war == null or not is_instance_valid(fog_of_war):
		fog_of_war = FOG_OF_WAR_SCRIPT.new()
		add_child(fog_of_war)
	fog_of_war.reset_visits()
	# Clear any surviving enemies before replacing the geometry.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()
	if is_instance_valid(dungeon_portal):
		dungeon_portal.queue_free()
	dungeon_portal = null
	for child in get_children():
		if child.name.begins_with("Gate_Room_"):
			remove_child(child)
			child.queue_free()

	for child in generated_rooms.get_children():
		generated_rooms.remove_child(child)
		child.queue_free()

	for child in generated_corridors.get_children():
		generated_corridors.remove_child(child)
		child.queue_free()

	connections.clear()
	room_encounters.clear()
	rooms_entered = 0
	boss_room_created = false
	boss_spawned = false
	boss_instance = null
	connections[Vector2i.ZERO] = []

	var attempts := 0

	while connections.size() < room_count and attempts < 1000:
		attempts += 1
		var candidates: Array[Vector2i] = []

		for cell in connections.keys():
			if connections[cell].size() < 3:
				candidates.append(cell)

		if candidates.is_empty():
			break

		var parent: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
		var available: Array[Vector2i] = []

		for direction in DIRECTIONS:
			var neighbor: Vector2i = parent + direction

			if connections.has(neighbor):
				continue

			var touches_other_room := false

			for check_direction in DIRECTIONS:
				var adjacent: Vector2i = neighbor + check_direction

				if connections.has(adjacent) and adjacent != parent:
					touches_other_room = true
					break

			if not touches_other_room:
				available.append(direction)

		if available.is_empty():
			continue

		var chosen_direction: Vector2i = available[rng.randi_range(0, available.size() - 1)]
		var new_cell: Vector2i = parent + chosen_direction

		connections[new_cell] = [-chosen_direction]
		connections[parent].append(chosen_direction)

	# Generate all rooms.
	for cell in connections.keys():
		_place_room(cell, connections[cell])

	# Initialize minimap ONCE after generating all rooms.
	if minimap != null:
		minimap.setup_map(connections)
		print("MINIMAP CONNECTED: ", connections.size(), " rooms")
	else:
		print("ERROR: Minimap node not found!")

	# Generate corridors.
	var corridor_count := 0

	for cell in connections.keys():
		for direction in connections[cell]:
			var neighbor: Vector2i = cell + direction

			if cell.x < neighbor.x or (cell.x == neighbor.x and cell.y < neighbor.y):
				_create_corridor(cell, neighbor)
				corridor_count += 1
				print("Generated ", connections.size(), " rooms and ", corridor_count, " corridors.")

	# Cover all unoccupied terrain with one lightweight visual rock mesh.
	_rebuild_rock_fill()
	fog_of_war.rebuild(connections, get_room_size(),
		dungeon_settings.corridor_length, dungeon_settings.doorway_width, WALL_HEIGHT)
	fog_of_war.reveal_room(Vector2i.ZERO, connections)



func _rebuild_rock_fill() -> void:
	var previous := get_node_or_null("GeneratedRockFill")
	if previous != null:
		remove_child(previous)
		previous.queue_free()
	var fill: MeshInstance3D = ROCK_FILL.build(
		connections,
		get_room_size(),
		dungeon_settings.corridor_length,
		dungeon_settings.doorway_width,
		MINE_WALL_MATERIAL,
		WALL_HEIGHT
	)
	add_child(fill)

	# Reuse the lightweight exterior mesh as a continuous fog surface.
	# The fog script supplies the same material used by room/corridor covers.
	fill.position.y = (WALL_HEIGHT + 0) - (WALL_HEIGHT - 0.02)
	if fog_of_war != null and is_instance_valid(fog_of_war):
		fill.material_override = fog_of_war.get_fog_material()
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _place_room(cell: Vector2i, openings: Array) -> void:
	var scene: PackedScene
	var rotation_steps := 0
	if openings.size() == 1:
		scene = ROOM_DEAD_END
		rotation_steps = _find_rotation([Vector2i(0, 1)], openings)
	elif openings.size() == 2:
		if openings[0] + openings[1] == Vector2i.ZERO:
			scene = ROOM_STRAIGHT
			rotation_steps = _find_rotation([Vector2i(0, -1), Vector2i(0, 1)], openings)
		else:
			scene = ROOM_CORNER
			rotation_steps = _find_rotation([Vector2i(0, 1), Vector2i(1, 0)], openings)
	else:
		scene = ROOM_JUNCTION
		rotation_steps = _find_rotation([Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0)], openings)
	var room: Node3D = scene.instantiate()
	ROOM_RESIZER.resize_room(room, get_room_size(), dungeon_settings.doorway_width)
	generated_rooms.add_child(room)

# Randomize this room's floor and wall appearance.
	_randomize_room_materials(room)
	CAVE_DETAIL.decorate_room(room, rng)
	room.position = Vector3(cell.x * get_grid_spacing(), 0.0, cell.y * get_grid_spacing())
	room.rotation.y = rotation_steps * PI / 2.0
	room.name = "Room_%d_%d" % [cell.x, cell.y]

	var encounter := Node3D.new()
	encounter.name = "RoomEncounter"
	encounter.set_script(ROOM_ENCOUNTER_SCRIPT)
	encounter.enemy_scenes = dungeon_enemy_scenes

# Apply this map's centralized balance settings.
	_apply_encounter_balance(encounter)

	room.add_child(encounter)

	room_encounters[cell] = encounter
	encounter.progress_changed.connect(_on_room_progress_changed)
	encounter.encounter_started.connect(_on_room_encounter_started)
	encounter.encounter_completed.connect(_on_room_encounter_completed)
	encounter.encounter_completed.connect(_check_boss_unlock.call_deferred)
	if cell == Vector2i.ZERO:
		encounter.encounter_cleared = true
	for direction in openings:
		var gate: Node3D = GATE_SCENE.instantiate()

		gate.name = "Gate_Room_%d_%d_Dir_%d_%d" % [
			cell.x, cell.y, direction.x, direction.y
		]

		# Calculate absolute dungeon coordinates.
		var room_x: float = float(cell.x) * get_grid_spacing()
		var room_z: float = float(cell.y) * get_grid_spacing()

		var gate_x: float = room_x + float(direction.x) * get_room_size() * 0.5
		var gate_z: float = room_z + float(direction.y) * get_room_size() * 0.5

		# Add gate to the dungeon root.
		add_child(gate)

		# Set the gate's WORLD position.
		gate.global_position = Vector3(gate_x, 0.0, gate_z)

		# Align the gate with the doorway.
		if direction.x != 0:
			gate.global_rotation.y = PI / 2.0
		else:
			gate.global_rotation.y = 0.0

		encounter.register_door(gate)


func _find_rotation(default_openings: Array, target_openings: Array) -> int:
	for steps in range(4):
		var matches := true
		for direction in default_openings:
			if not target_openings.has(_rotate_direction(direction, steps)):
				matches = false
				break
		if matches:
			return steps
	push_warning("Could not match room rotation.")
	return 0

func _randomize_room_materials(room: Node3D) -> void:
	# Pick one random floor and wall material for this room.
	var floor_material: StandardMaterial3D = null
	var wall_material: StandardMaterial3D = null

	if not floor_materials.is_empty():
		floor_material = floor_materials.pick_random()

	if not wall_materials.is_empty():
		wall_material = wall_materials.pick_random()

	# Apply materials to the room's existing meshes.
	for child in room.get_children():
		if not child is StaticBody3D:
			continue

		var mesh := child.get_node_or_null("MeshInstance3D") as MeshInstance3D

		if mesh == null:
			continue

		if child.name == "RoomFloor":
			if floor_material != null:
				mesh.material_override = floor_material
		else:
			if wall_material != null:
				mesh.material_override = wall_material

func _rotate_direction(direction: Vector2i, steps: int) -> Vector2i:
	var result := direction
	for i in range(steps):
		result = Vector2i(result.y, -result.x)
	return result

func _create_corridor(from_cell: Vector2i, to_cell: Vector2i) -> void:
	var delta: Vector2i = to_cell - from_cell
	var center := Vector3((from_cell.x + to_cell.x) * get_grid_spacing() * 0.5, 0.0, (from_cell.y + to_cell.y) * get_grid_spacing() * 0.5)
	var corridor := Node3D.new()
	corridor.name = "Corridor"
	generated_corridors.add_child(corridor)
	corridor.position = center
	if delta.x != 0:
		_add_box(corridor, "Floor", Vector3(dungeon_settings.corridor_length, 0.5, dungeon_settings.doorway_width), Vector3(0, -0.25, 0))
		_add_box(corridor, "WallNorth", Vector3(dungeon_settings.corridor_length, WALL_HEIGHT, 1), Vector3(0, WALL_HEIGHT / 2.0, -(dungeon_settings.doorway_width + 1.0) * 0.5))
		var south_wall := _add_box(corridor, "WallSouth", Vector3(dungeon_settings.corridor_length, WALL_HEIGHT, 1), Vector3(0, WALL_HEIGHT / 2.0, (dungeon_settings.doorway_width + 1.0) * 0.5))
		_apply_translucent_material(south_wall)
	else:
		_add_box(corridor, "Floor", Vector3(dungeon_settings.doorway_width, 0.5, dungeon_settings.corridor_length), Vector3(0, -0.25, 0))
		_add_box(corridor, "WallWest", Vector3(1, WALL_HEIGHT, dungeon_settings.corridor_length), Vector3(-(dungeon_settings.doorway_width + 1.0) * 0.5, WALL_HEIGHT / 2.0, 0))
		_add_box(corridor, "WallEast", Vector3(1, WALL_HEIGHT, dungeon_settings.corridor_length), Vector3((dungeon_settings.doorway_width + 1.0) * 0.5, WALL_HEIGHT / 2.0, 0))

func _apply_translucent_material(wall: StaticBody3D) -> void:
	var wall_mesh := wall.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if wall_mesh == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.65, 0.65, 0.65, south_wall_opacity)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	wall_mesh.material_override = material

func _add_box(parent: Node3D, box_name: String, size: Vector3, local_position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = box_name
	parent.add_child(body)
	body.position = local_position

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	body.add_child(mesh_instance)

	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh

	# Apply the correct dungeon material.
	if box_name == "Floor":
		mesh_instance.material_override = MINE_FLOOR_MATERIAL
	else:
		mesh_instance.material_override = MINE_WALL_MATERIAL

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	body.add_child(collision_shape)

	var box_shape := BoxShape3D.new()
	box_shape.size = size
	collision_shape.shape = box_shape

	return body

func _create_room_progress_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "RoomProgressHUD"
	add_child(canvas)

	var container := VBoxContainer.new()
	canvas.add_child(container)
	# Anchor the room progress HUD to the top-right of the viewport.
	container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	container.offset_left = -420.0
	container.offset_top = 24.0
	container.offset_right = -20.0
	container.offset_bottom = 76.0
	container.custom_minimum_size = Vector2(400, 52)

	room_progress_label = Label.new()
	room_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_progress_label.text = "ROOM CLEAR: 0 / 10"
	container.add_child(room_progress_label)

	room_progress_bar = ProgressBar.new()
	room_progress_bar.custom_minimum_size = Vector2(400, 22)
	room_progress_bar.min_value = 0
	room_progress_bar.max_value = 10
	room_progress_bar.value = 0
	room_progress_bar.show_percentage = false
	container.add_child(room_progress_bar)

	container.visible = false


func _on_room_encounter_started() -> void:
	room_progress_bar.get_parent().visible = true

	# Start the run clock on the first combat encounter only.
	# Search the entire scene tree because the HUD may be a sibling
	# of the dungeon generator rather than one of its children.
	for node in get_tree().root.find_children("*", "TextureRect", true, false):
		if node.has_method("start_timer") and node.get_node_or_null("DungeonTimerLabel") != null:
			node.start_timer()
			return

	push_warning("Dungeon timer not found: check the TextureRect with DungeonTimerLabel.")


func _on_room_progress_changed(kills: int, required: int) -> void:
	room_progress_bar.max_value = required
	room_progress_bar.value = kills
	room_progress_label.text = "ROOM CLEAR: %d / %d" % [kills, required]


func _on_room_encounter_completed() -> void:
	room_progress_label.text = "ROOM CLEARED!"


# Unlock only after all 11 non-starting encounters have finished.
func _check_boss_unlock() -> void:
	if boss_room_created or boss_scene == null:
		return
	for cell in room_encounters.keys():
		if cell == Vector2i.ZERO:
			continue
		if not room_encounters[cell].encounter_cleared:
			return
	_create_boss_room()


func _create_boss_room() -> void:
	# Prefer a distant dead end, keeping the generated dungeon intact.
	var candidates: Array[Vector2i] = []
	for cell in connections.keys():
		if cell != Vector2i.ZERO and connections[cell].size() == 1:
			candidates.append(cell)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return abs(a.x) + abs(a.y) > abs(b.x) + abs(b.y))

	var parent_cell := Vector2i.ZERO
	var chosen_direction := Vector2i.ZERO
	var found := false
	for candidate in candidates:
		for direction in DIRECTIONS:
			var neighbor: Vector2i = candidate + direction
			if connections.has(neighbor):
				continue
			var touches_other := false
			for check_dir in DIRECTIONS:
				if connections.has(neighbor + check_dir) and neighbor + check_dir != candidate:
					touches_other = true
					break
			if not touches_other:
				parent_cell = candidate
				chosen_direction = direction
				found = true
				break
		if found:
			break
	if not found:
		push_error("Boss room: no free dead-end connection available.")
		return

	boss_room_cell = parent_cell + chosen_direction
	# Remove the old end room and its gates so its wall becomes a doorway.
	var old_room := generated_rooms.get_node_or_null("Room_%d_%d" % [parent_cell.x, parent_cell.y])
	if old_room != null:
		generated_rooms.remove_child(old_room)
		old_room.queue_free()
	for child in get_children():
		if child.name.begins_with("Gate_Room_%d_%d_Dir_" % [parent_cell.x, parent_cell.y]):
			remove_child(child)
			child.queue_free()
	room_encounters.erase(parent_cell)

	connections[parent_cell].append(chosen_direction)
	connections[boss_room_cell] = [-chosen_direction]
	_place_room(parent_cell, connections[parent_cell])
	room_encounters[parent_cell].encounter_cleared = true
	_place_room(boss_room_cell, connections[boss_room_cell])
	# The boss room uses a boss, not the ordinary enemy spawner.
	room_encounters[boss_room_cell].encounter_cleared = true
	_create_corridor(parent_cell, boss_room_cell)
	_rebuild_rock_fill()  # Open the new boss route in the surrounding rock.
	fog_of_war.rebuild(connections, get_room_size(),
		dungeon_settings.corridor_length, dungeon_settings.doorway_width, WALL_HEIGHT)
	boss_room_created = true
	if minimap != null and minimap.has_method("reveal_boss_room"):
		minimap.reveal_boss_room(boss_room_cell, connections)
	print("BOSS ROOM UNLOCKED: ", boss_room_cell)


func _spawn_boss() -> void:
	if boss_spawned or boss_scene == null:
		return
	var boss := boss_scene.instantiate() as Node3D
	if boss == null:
		push_error("Boss scene must have a Node3D root.")
		return
	boss_spawned = true
	boss_instance = boss

	# Match the room-based scaling used by normal encounters.
	var difficulty: int = (dungeon_floor - 1) * (room_count - 1) + room_count
	var extra_rooms: int = maxi(0, difficulty - 1)
	var template_encounter = room_encounters[boss_room_cell]
	var health_multiplier: float = 1.0 + float(extra_rooms) * template_encounter.health_increase_per_room
	var damage_multiplier: float = 1.0 + float(extra_rooms) * template_encounter.damage_increase_per_room

	# Boss.gd uses boss_max_health, not max_health.
	if _boss_has_property(boss, "boss_max_health"):
		var base_health: int = int(boss.get("boss_max_health"))
		var scaled_health: int = maxi(1, roundi(float(base_health) * health_multiplier))
		var minimum_health: int = 1800 + maxi(0, dungeon_floor - 1) * 600
		boss.set("boss_max_health", maxi(scaled_health, minimum_health))
	else:
		push_warning("Boss is missing boss_max_health; health scaling was not applied.")

	# Scale the attack variables actually declared by Boss.gd.
	var boss_damage_properties: Array[String] = [
		"contact_damage",
		"charge_damage",
		"slam_damage",
		"combo_damage"
	]
	for property_name in boss_damage_properties:
		if _boss_has_property(boss, property_name):
			boss.set(
				property_name,
				maxi(1, roundi(float(boss.get(property_name)) * damage_multiplier))
			)

	if not boss.has_method("take_damage"):
		push_error("Boss.gd does not implement take_damage(amount). Player shots may not damage it.")
	if boss is CollisionObject3D:
		boss.collision_layer = boss.collision_layer | 2
	boss.tree_exiting.connect(_on_boss_exiting.bind(boss))
	get_tree().current_scene.add_child(boss)
	boss.global_position = Vector3(boss_room_cell.x * get_grid_spacing(), boss_spawn_height, boss_room_cell.y * get_grid_spacing())

	# Boss._ready() initializes health from boss_max_health; synchronize it here too.
	if _boss_has_property(boss, "health") and _boss_has_property(boss, "boss_max_health"):
		boss.set("health", boss.get("boss_max_health"))

	print(
		"BOSS SPAWNED | Floor: ", dungeon_floor,
		" | HP: ", boss.get("boss_max_health") if _boss_has_property(boss, "boss_max_health") else "unknown",
		" | Damage multiplier: ", damage_multiplier
	)


func _boss_has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if property["name"] == property_name:
			return true
	return false


func _on_boss_exiting(boss: Node3D) -> void:
	# Boss scripts usually queue_free() when health reaches zero.
	# Do not open a portal if the boss is removed for another reason.
	var defeated := false
	for field in ["current_health", "health"]:
		if _boss_has_property(boss, field):
			defeated = int(boss.get(field)) <= 0
			break
	if defeated:
		_spawn_exit_portal.call_deferred()
	else:
		push_warning("Boss removed without health <= 0; no portal spawned.")


func _spawn_exit_portal() -> void:
	if is_instance_valid(dungeon_portal):
		return
	dungeon_portal = Node3D.new()
	dungeon_portal.name = "DungeonExitPortal"
	dungeon_portal.set_script(PORTAL_SCRIPT)
	get_tree().current_scene.add_child(dungeon_portal)
	dungeon_portal.global_position = Vector3(
		boss_room_cell.x * get_grid_spacing(), 0.05,
		boss_room_cell.y * get_grid_spacing()
	)
	dungeon_portal.portal_entered.connect(_enter_next_floor)
	print("BOSS DEFEATED - EXIT PORTAL SPAWNED")


func _enter_next_floor() -> void:
	if player == null or not is_instance_valid(player):
		return
	set_physics_process(false)
	player.set_physics_process(false)
	dungeon_floor += 1
	generate_dungeon()
	if floor_label != null:
		floor_label.text = "DUNGEON FLOOR %d" % dungeon_floor
	if room_progress_bar != null:
		room_progress_bar.get_parent().visible = false
	_place_player_at_start.call_deferred()
	set_physics_process.call_deferred(true)
	print("ENTERED DUNGEON FLOOR ", dungeon_floor, " - PLAYER UPGRADES PRESERVED")


func _create_floor_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "DungeonFloorHUD"
	add_child(canvas)
	floor_label = Label.new()
	floor_label.text = "DUNGEON FLOOR %d" % dungeon_floor
	floor_label.position = Vector2(20, 80)
	floor_label.add_theme_font_size_override("font_size", 23)
	canvas.add_child(floor_label)


func _apply_encounter_balance(encounter: Node3D) -> void:
	if balance_profile == null:
		return

	encounter.set("configured_health_multiplier", balance_profile.health_multiplier)
	encounter.set("configured_damage_multiplier", balance_profile.damage_multiplier)
	encounter.set("configured_speed_multiplier", balance_profile.speed_multiplier)
	encounter.set("configured_elite_chance", balance_profile.elite_chance)

	# Configure normal enemy currency rewards.
	encounter.set("configured_currency_drop_chance", balance_profile.gold_drop_chance)
	encounter.set("configured_currency_min_drop", balance_profile.gold_minimum)
	encounter.set("configured_currency_max_drop", balance_profile.gold_maximum)

	# Configure elite enemy currency rewards.
	encounter.set("configured_elite_currency_drop_chance", balance_profile.elite_gold_drop_chance)
	encounter.set("configured_elite_currency_min_drop", balance_profile.elite_gold_minimum)
	encounter.set("configured_elite_currency_max_drop", balance_profile.elite_gold_maximum)




	# Build a properly typed array for the room encounter.
	var spawn_weights: Array[int] = [
		balance_profile.stalker_weight,
		balance_profile.charger_weight,
		balance_profile.brute_weight,
		balance_profile.regular_weight,
		balance_profile.ranged_weight
	]

	encounter.set("enemy_spawn_weights", spawn_weights)

	print("Dungeon enemy weights assigned: ", spawn_weights)



	# Base encounter settings.
	encounter.set(
		"kills_required",
		balance_profile.dungeon_kills_required
	)
	encounter.set(
		"max_alive",
		balance_profile.dungeon_max_alive
	)
	encounter.set(
		"initial_spawn_count",
		balance_profile.dungeon_initial_spawn
	)
	encounter.set(
		"enemies_per_spawn_tick",
		balance_profile.dungeon_enemies_per_tick
	)
	encounter.set(
		"spawn_interval",
		balance_profile.dungeon_spawn_interval
	)

	# Difficulty scaling per room.
	encounter.set(
		"health_increase_per_room",
		balance_profile.dungeon_health_increase_per_room
	)
	encounter.set(
		"damage_increase_per_room",
		balance_profile.dungeon_damage_increase_per_room
	)
	encounter.set(
		"enemy_count_increase_per_room",
		balance_profile.dungeon_enemy_count_increase_per_room
	)
	encounter.set(
		"extra_alive_every_rooms",
		balance_profile.dungeon_extra_alive_every_rooms
	)
	encounter.set(
		"spawn_speed_increase_per_room",
		balance_profile.dungeon_spawn_speed_increase_per_room
	)
	encounter.set(
		"minimum_spawn_interval",
		balance_profile.dungeon_minimum_spawn_interval
	)
