
extends Label3D

@export_group("General")
@export var duration: float = 1.15
@export var float_height: float = 1.45
@export var horizontal_spread: float = 0.55
@export var vertical_spread: float = 0.15

@export_group("Normal Damage")
@export var normal_font_size: int = 48
@export var normal_color: Color = Color.WHITE
@export var normal_outline_size: int = 10

@export_group("Critical Damage")
@export var critical_font_size: int = 72
@export var critical_color: Color = Color("#FFD529")
@export var critical_outline_size: int = 14

@export_group("Animation")
@export var normal_pop_scale: float = 1.35
@export var critical_pop_scale: float = 1.95
@export var pop_duration: float = 0.16
@export var fade_start: float = 0.70
@export var drift_strength: float = 0.18

var elapsed: float = 0.0
var start_position: Vector3 = Vector3.ZERO
var is_critical: bool = false

var base_scale: Vector3 = Vector3.ONE
var movement_offset: Vector3 = Vector3.ZERO
var random_side: float = 0.0
var animation_started: bool = false


func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	fixed_size = false
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	double_sided = true
	shaded = false

	# Keep the larger font readable in the 3D world.
	pixel_size = 0.005

	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	outline_modulate = Color.BLACK

	base_scale = scale
	start_position = global_position

	apply_damage_style()

	if not animation_started:
		_begin_animation()


func setup(amount: int, critical: bool = false) -> void:
	text = str(amount)
	is_critical = critical
	elapsed = 0.0

	apply_damage_style()

	if is_inside_tree():
		_begin_animation()
	else:
		animation_started = false


func apply_damage_style() -> void:
	if is_critical:
		font_size = critical_font_size
		outline_size = critical_outline_size
		modulate = critical_color
		outline_modulate = Color(0.15, 0.04, 0.0, 1.0)
	else:
		font_size = normal_font_size
		outline_size = normal_outline_size
		modulate = normal_color
		outline_modulate = Color.BLACK


func _begin_animation() -> void:
	animation_started = true
	elapsed = 0.0

	start_position = global_position

	random_side = randf_range(-1.0, 1.0)

	if absf(random_side) < 0.25:
		random_side = 0.25 if random_side >= 0.0 else -0.25

	movement_offset = Vector3(
		randf_range(-horizontal_spread, horizontal_spread),
		randf_range(-vertical_spread, vertical_spread),
		0.0
	)

	start_position += movement_offset
	global_position = start_position

	var pop_scale: float = normal_pop_scale

	if is_critical:
		pop_scale = critical_pop_scale

	scale = base_scale * pop_scale

	modulate.a = 1.0
	outline_modulate.a = 1.0


func _process(delta: float) -> void:
	if not animation_started:
		return

	elapsed += delta

	var safe_duration: float = maxf(duration, 0.01)
	var progress: float = clampf(elapsed / safe_duration, 0.0, 1.0)

	_update_movement(progress)
	_update_scale()
	_update_fade(progress)

	if elapsed >= safe_duration:
		queue_free()


func _update_movement(progress: float) -> void:
	# Fast initial rise that gradually slows.
	var rise_progress: float = 1.0 - pow(1.0 - progress, 2.0)

	var upward_movement: float = float_height * rise_progress

	# Slight sideways movement, similar to WoW damage numbers.
	var sideways_movement: float = random_side * drift_strength * progress

	global_position = start_position + Vector3(
		sideways_movement,
		upward_movement,
		0.0
	)


func _update_scale() -> void:
	var safe_pop_duration: float = maxf(pop_duration, 0.01)
	var pop_progress: float = clampf(elapsed / safe_pop_duration, 0.0, 1.0)

	var starting_scale: float = normal_pop_scale

	if is_critical:
		starting_scale = critical_pop_scale

	# Oversized impact followed by a quick settle.
	var eased_progress: float = 1.0 - pow(1.0 - pop_progress, 3.0)

	var current_scale: float = lerpf(
		starting_scale,
		1.0,
		eased_progress
	)

	scale = base_scale * current_scale


func _update_fade(progress: float) -> void:
	var alpha: float = 1.0

	if progress > fade_start:
		var fade_progress: float = (
			(progress - fade_start) /
			maxf(1.0 - fade_start, 0.01)
		)

		alpha = 1.0 - smoothstep(0.0, 1.0, fade_progress)

	modulate.a = alpha
	outline_modulate.a = alpha
