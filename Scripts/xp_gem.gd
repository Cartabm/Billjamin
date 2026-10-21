
extends Area3D

@export_group("XP")
@export var xp_value: int = 1
@export var attraction_speed: float = 10.0
@export var collect_distance: float = 0.5

@export_group("Merging")
@export var merge_after_seconds: float = 0.0
@export var merge_radius: float = 2.5
@export var merge_check_interval: float = 0.5

@export_group("Visuals")
@export var rotation_speed: float = 1.5
@export var bob_height: float = 0.12
@export var bob_speed: float = 3.0

@onready var gem_visual: Node3D = get_node_or_null("GemVisual")

var age: float = 0.0
var is_merged_gem: bool = false
var is_merging: bool = false
var is_collected: bool = false

var player: Node3D
var attracted: bool = false
var magnet_attracted: bool = false

var animation_time: float = 0.0
var starting_height: float = 0.0
var merge_check_timer: float = 0.0


func _ready() -> void:
	add_to_group("xp_gems")
	body_entered.connect(_on_body_entered)

	player = _find_player()

	if gem_visual != null:
		starting_height = gem_visual.position.y

	# Stagger merge checks so every gem does not scan simultaneously.
	merge_check_timer = randf_range(0.0, merge_check_interval)


func _process(delta: float) -> void:
	if is_collected or is_queued_for_deletion():
		return

	animation_time += delta
	age += delta
	merge_check_timer -= delta

	if gem_visual != null:
		gem_visual.rotation.y += rotation_speed * delta
		gem_visual.position.y = starting_height + sin(
			animation_time * bob_speed
		) * bob_height

	if age >= merge_after_seconds and merge_check_timer <= 0.0:
		merge_check_timer = maxf(merge_check_interval, 0.1)
		merge_nearby_gems()


func _physics_process(delta: float) -> void:
	if is_collected or is_merging:
		return

	if player == null or not is_instance_valid(player):
		player = _find_player()

	if player == null:
		return

	if attracted:
		var target_position := player.global_position + Vector3(0.0, 0.5, 0.0)

		global_position = global_position.move_toward(
			target_position,
			attraction_speed * delta
		)

		if global_position.distance_to(target_position) <= collect_distance:
			collect_xp()


func _find_player() -> Node3D:
	var scene := get_tree().current_scene

	if scene != null:
		var found_player := scene.get_node_or_null("Player") as Node3D
		if found_player != null:
			return found_player

	for node in get_tree().get_nodes_in_group("player"):
		if node is Node3D:
			return node as Node3D

	return null


func activate_magnet_attraction() -> void:
	attracted = true
	magnet_attracted = true


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		attracted = true


func collect_xp() -> void:
	if is_collected:
		return

	is_collected = true

	if player == null or not is_instance_valid(player):
		player = _find_player()

	if player != null and player.has_method("gain_xp"):
		player.call("gain_xp", xp_value)

	queue_free()


func can_merge() -> bool:
	return (
		not is_collected
		and not is_queued_for_deletion()
		and not attracted
		and not is_merging
		and age >= merge_after_seconds
	)


func merge_nearby_gems() -> void:
	if not can_merge():
		return

	var scene := get_tree().current_scene
	if scene == null:
		return

	# Lock this gem while merging to prevent overlapping merge operations.
	is_merging = true

	var nearby_gems := get_tree().get_nodes_in_group("xp_gems")

	var total_xp: int = xp_value
	var merged_count: int = 0

	for node in nearby_gems:
		if node == self or not is_instance_valid(node):
			continue

		if not node.has_method("can_merge"):
			continue

		if not node.can_merge():
			continue

		var other := node as Area3D
		if other == null:
			continue

		if global_position.distance_to(other.global_position) > merge_radius:
			continue

		# Claim the other gem before reading its value so it cannot
		# be consumed by another merge during the same frame.
		other.set("is_merging", true)

		total_xp += int(other.get("xp_value"))
		other.queue_free()
		merged_count += 1

	if merged_count > 0:
		xp_value = total_xp
		set_merged_appearance()

	is_merging = false


func set_merged_appearance() -> void:
	is_merged_gem = true

	if gem_visual == null:
		return

	for node in gem_visual.find_children(
		"*",
		"MeshInstance3D",
		true,
		false
	):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null:
			continue

		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.7, 0.2, 1.0)
		material.emission_enabled = true
		material.emission = Color(0.5, 0.1, 1.0)
		material.emission_energy_multiplier = 1.5
		mesh_instance.material_override = material
