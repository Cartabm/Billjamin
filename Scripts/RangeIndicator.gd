extends Node3D
## One lightweight player-only component; no physics queries or mesh rebuilding.
## F3 cycles Always -> Hold Left Alt -> Off.

const MODE_ALWAYS: int = 0
const MODE_HOLD: int = 1
const MODE_OFF: int = 2

var display_mode: int = MODE_ALWAYS
var player: CharacterBody3D
var range_mesh: MeshInstance3D
var target_mesh: MeshInstance3D
var refresh_timer: float = 0.0

func _ready() -> void:
	player = get_parent() as CharacterBody3D
	if player == null:
		set_process(false)
		return
	range_mesh = CombatVisualManager.create_range_indicator(self)
	target_mesh = CombatVisualManager.create_target_marker(self)
	_refresh()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		display_mode = (display_mode + 1) % 3
		_refresh()

func _process(delta: float) -> void:
	if player.is_dead or player.run_ended:
		range_mesh.visible = false
		target_mesh.visible = false
		return
	refresh_timer -= delta
	if refresh_timer <= 0.0:
		refresh_timer = 0.10
		_refresh()

func _refresh() -> void:
	if not is_instance_valid(player) or not is_instance_valid(range_mesh):
		return
	var applicable: bool = player.has_method("get_basic_attack_range")
	if applicable and player.has_method("is_basic_range_indicator_applicable"):
		applicable = player.is_basic_range_indicator_applicable()
	var shown: bool = applicable and (display_mode == MODE_ALWAYS or (display_mode == MODE_HOLD and Input.is_key_pressed(KEY_ALT)))
	range_mesh.visible = shown
	target_mesh.visible = false
	if not shown:
		return
	var effective_range: float = maxf(0.01, float(player.get_basic_attack_range()))
	range_mesh.scale = Vector3(effective_range, 1.0, effective_range)
	var nearest: Node3D = null
	var nearest_distance: float = effective_range * effective_range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node3D or enemy.is_queued_for_deletion():
			continue
		var offset: Vector3 = enemy.global_position - player.global_position
		offset.y = 0.0
		var distance_squared: float = offset.length_squared()
		if distance_squared < nearest_distance:
			nearest = enemy
			nearest_distance = distance_squared
	if nearest != null:
		target_mesh.global_position = nearest.global_position + Vector3(0.0, 0.14, 0.0)
		target_mesh.visible = true
