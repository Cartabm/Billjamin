
extends Control

@export_range(0.0, 2.0, 0.05) var animation_duration: float = 0.35

@onready var health_fill: TextureRect = $HealthFill
@onready var curved_hp_text: Control = $CurvedHPText
@onready var xp_fill: TextureRect = $XPFill
@onready var level_label: Label = $LevelLabel
@onready var dodge_cooldown_bar: ProgressBar = $DodgeCooldownBar

var displayed_xp_percent: float = 0.0
var xp_tween: Tween
var displayed_percent: float = 1.0
var health_tween: Tween


func _ready() -> void:
	set_health_immediate(1.0)


func set_health_immediate(percent: float) -> void:
	if health_tween and health_tween.is_running():
		health_tween.kill()

	displayed_percent = clampf(percent, 0.0, 1.0)
	_update_shader(displayed_percent)


func animate_health(percent: float) -> void:
	var target_percent: float = clampf(percent, 0.0, 1.0)

	if health_tween and health_tween.is_running():
		health_tween.kill()

	health_tween = create_tween()
	health_tween.set_trans(Tween.TRANS_SINE)
	health_tween.set_ease(Tween.EASE_OUT)
	health_tween.tween_method(
		_update_shader,
		displayed_percent,
		target_percent,
		animation_duration
	)


func set_health_values(current_hp: float, maximum_hp: float) -> void:
	var safe_max: float = maxf(1.0, maximum_hp)
	var safe_current: float = clampf(current_hp, 0.0, safe_max)

	if curved_hp_text != null:
		curved_hp_text.set("hp_current", roundi(safe_current))
		curved_hp_text.set("hp_max", roundi(safe_max))


func _update_shader(percent: float) -> void:
	displayed_percent = percent

	if health_fill == null:
		health_fill = get_node_or_null("HealthFill") as TextureRect

	if health_fill == null:
		push_warning("PlayerHealthBar: HealthFill not found.")
		return

	var shader_material := health_fill.material as ShaderMaterial

	if shader_material:
		shader_material.set_shader_parameter("health_percent", percent)
	else:
		push_warning("PlayerHealthBar: ShaderMaterial not found.")


func set_xp_immediate(percent: float) -> void:
	if xp_tween and xp_tween.is_running():
		xp_tween.kill()

	_update_xp_shader(clampf(percent, 0.0, 1.0))


func animate_xp(percent: float) -> void:
	var target_percent := clampf(percent, 0.0, 1.0)

	if xp_tween and xp_tween.is_running():
		xp_tween.kill()

	xp_tween = create_tween()
	xp_tween.set_trans(Tween.TRANS_SINE)
	xp_tween.set_ease(Tween.EASE_OUT)
	xp_tween.tween_method(
		_update_xp_shader,
		displayed_xp_percent,
		target_percent,
		animation_duration
	)


func _update_xp_shader(percent: float) -> void:
	displayed_xp_percent = percent

	if not is_instance_valid(xp_fill):
		return

	var shader_material := xp_fill.material as ShaderMaterial

	if shader_material:
		shader_material.set_shader_parameter(
			"xp_percent",
			percent
		)
func set_player_level(level: int) -> void:
	if is_instance_valid(level_label):
		level_label.text = str(level)

func set_dodge_energy(current_energy: float, maximum_energy: float) -> void:
	if not is_instance_valid(dodge_cooldown_bar):
		return

	dodge_cooldown_bar.value = (
		clampf(current_energy / maxf(maximum_energy, 1.0), 0.0, 1.0)
		* 100.0
	)
