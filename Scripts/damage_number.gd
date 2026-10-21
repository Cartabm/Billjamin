
extends Label3D

@export_group("General")
@export var duration: float = 1.15
@export var float_height: float = 1.25
@export var horizontal_spread: float = 0.55
@export var vertical_spread: float = 0.15

@export_group("Normal Damage")
@export var normal_font_size: int = 80
@export var normal_color: Color = Color.WHITE
@export var normal_outline_size: int = 18

@export_group("Critical Damage")
@export var critical_font_size: int = 110
@export var critical_color: Color = Color("#FFD529")
@export var critical_outline_size: int = 24

@export_group("Critical Pop")
@export var critical_expand_time: float = 0.05
@export var critical_settle_time: float = 0.20
@export var critical_peak_scale: float = 1.55
@export var critical_final_scale: float = 1.12

@export_group("Number Separation")
@export var push_radius: float = 1.6
@export var push_distance: float = 0.40
@export var push_duration: float = 0.10

@export_group("Fade")
@export var fade_start: float = 0.70
@export var drift_strength: float = 0.18

var elapsed: float = 0.0
var is_critical: bool = false
var animation_started: bool = false

var base_scale: Vector3 = Vector3.ONE
var start_position: Vector3 = Vector3.ZERO
var random_side: float = 0.0
var push_offset: Vector3 = Vector3.ZERO


func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	fixed_size = false
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	double_sided = true
	shaded = false

	pixel_size = 0.005

	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	base_scale = scale
	start_position = global_position

	add_to_group("floating_damage_numbers")

	apply_damage_style()

	if not animation_started:
		_begin_animation()


func setup(amount: int, critical: bool = false) -> void:
	is_critical = critical
	text = str(amount) + ("!" if critical else "")

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
		outline_modulate = Color("#542009")
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

	start_position += Vector3(
		randf_range(-horizontal_spread, horizontal_spread),
		randf_range(-vertical_spread, vertical_spread),
		0.0
	)

	global_position = start_position

	push_offset = Vector3.ZERO

	# Critical numbers start visually close to normal size.
	if is_critical:
		scale = base_scale * (
			float(normal_font_size) /
			float(maxi(critical_font_size, 1))
		)
	else:
		scale = base_scale

	modulate.a = 1.0
	outline_modulate.a = 1.0

	if is_critical:
		_push_nearby_numbers()


func _push_nearby_numbers() -> void:
	for node in get_tree().get_nodes_in_group(
		"floating_damage_numbers"
	):
		if node == self:
			continue

		if not node is Label3D:
			continue

		if not node.has_method("receive_crit_push"):
			continue

		if node.is_queued_for_deletion():
			continue

		var offset: Vector3 = (
			node.global_position - global_position
		)

		offset.y = 0.0

		var distance: float = offset.length()

		if distance > push_radius:
			continue

		# Push left or right rather than covering the number.
		var push_direction: float = 1.0

		if offset.x < 0.0:
			push_direction = -1.0

		var strength: float = (
			1.0 - distance / maxf(push_radius, 0.01)
		)

		node.receive_crit_push(
			Vector3(
				push_direction * push_distance * strength,
				0.0,
				0.0
			),
			push_duration
		)


func receive_crit_push(
	offset: Vector3,
	animation_time: float
) -> void:
	# Keep previous numbers visible; just separate them.
	var tween := create_tween()

	tween.tween_property(
		self,
		"push_offset",
		push_offset + offset,
		maxf(animation_time, 0.01)
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if not animation_started:
		return

	elapsed += delta

	var safe_duration: float = maxf(duration, 0.01)
	var progress: float = clampf(
		elapsed / safe_duration,
		0.0,
		1.0
	)

	_update_movement(progress)
	_update_scale()
	_update_fade(progress)

	if elapsed >= safe_duration:
		queue_free()


func _update_movement(progress: float) -> void:
	var rise_progress: float = (
		1.0 - pow(1.0 - progress, 2.0)
	)

	global_position = (
		start_position
		+ Vector3(
			random_side * drift_strength * progress,
			float_height * rise_progress,
			0.0
		)
		+ push_offset
	)


func _update_scale() -> void:
	if not is_critical:
		scale = base_scale
		return

	var expand_time: float = maxf(
		critical_expand_time,
		0.001
	)

	var settle_time: float = maxf(
		critical_settle_time,
		0.001
	)

	var starting_scale: float = (
		float(normal_font_size) /
		float(maxi(critical_font_size, 1))
	)

	var current_scale: float = critical_final_scale

	if elapsed < expand_time:
		var t: float = clampf(
			elapsed / expand_time,
			0.0,
			1.0
		)

		# Explosive expansion in roughly three frames.
		t = 1.0 - pow(1.0 - t, 3.0)

		current_scale = lerpf(
			starting_scale,
			critical_peak_scale,
			t
		)

	elif elapsed < expand_time + settle_time:
		var t: float = clampf(
			(elapsed - expand_time) / settle_time,
			0.0,
			1.0
		)

		t = 1.0 - pow(1.0 - t, 3.0)

		current_scale = lerpf(
			critical_peak_scale,
			critical_final_scale,
			t
		)

	scale = base_scale * current_scale


func _update_fade(progress: float) -> void:
	var alpha: float = 1.0

	if progress > fade_start:
		var fade_progress: float = (
			(progress - fade_start) /
			maxf(1.0 - fade_start, 0.01)
		)

		alpha = 1.0 - smoothstep(
			0.0,
			1.0,
			fade_progress
		)

	modulate.a = alpha
	outline_modulate.a = alpha
