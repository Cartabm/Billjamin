extends "res://Scripts/player_base.gd"

@export_group("Developer Testing")
@export var auto_fire_enabled: bool = false
@export var Auto_fire_range: float = 15
@export_range(0.0, 1.0, 0.01) var critical_hit_chance: float = 0.05
@export var critical_damage_multiplier: float = 2.0
@export_group("Damage Variation")
@export_range(0.0, 2.0, 0.01) var minimum_damage_multiplier: float = 0.80
@export_range(0.0, 3.0, 0.01) var maximum_damage_multiplier: float = 1.20
@onready var bow_sound: AudioStreamPlayer3D = get_node_or_null("BowSound")
@onready var hurt_sound: AudioStreamPlayer3D = get_node_or_null("HurtSound")
@onready var death_sound: AudioStreamPlayer = get_node_or_null("DeathSound")
@export var turn_speed: float = 10.0
@export var animation_player: AnimationPlayer
@export var use_archer_animations: bool = false
@export var archer_animation_player: AnimationPlayer
@export var archer_visual: Node3D
@export var face_camera_direction: bool = false
@export var health_bar_feet_offset: float = 0.25
@export var health_bar_screen_offset: Vector2 = Vector2(0, 10)

var dodge_timer: float = 0.0
var is_dodging: bool = false
var dodge_start_visual_rotation_x: float = 0.0
var current_animation: StringName = &""
var archer_action_time: float = 0.0
var archer_action: StringName = &""
var contact_damage_timer: float = 0.0
var fire_cooldown: float = 0.0
var admin_panel: Panel = null
var admin_multishot_label: Label = null
var admin_godmode_label: Label = null
var admin_godmode_button: Button = null

var fps_visible: bool = false

const TRAINING_DUMMY_SCENE: PackedScene = preload("res://Scenes/training_dummy.tscn")
const GUN_SHOT_DURATION: float = 0.433

@onready var character_sprite: AnimatedSprite3D = get_node_or_null("CharacterSprite")



@onready var level_up_sound: AudioStreamPlayer = get_node_or_null(
	"LevelUpSound"
) as AudioStreamPlayer

@onready var fps_label: Label = get_tree().current_scene.get_node_or_null(
	"FPSDisplay/FPSLabel"
) as Label

@onready var player_mesh: MeshInstance3D = get_node_or_null(
	"MeshInstance3D"
) as MeshInstance3D

@onready var player_visual: Node3D = get_node_or_null(
    "Billjamin_Archer_V5"
) as Node3D

@onready var camera: Camera3D = get_viewport().get_camera_3d()

@onready var xp_label: Label = get_tree().current_scene.get_node_or_null(
	"CanvasLayer/XPLabel"
) as Label

@onready var health_label: Label = get_tree().current_scene.get_node_or_null(
	"CanvasLayer/HealthLabel"
) as Label

@onready var game_over_menu: Control = get_tree().current_scene.get_node_or_null(
	"CanvasLayer/GameOverMenu"
) as Control

@onready var restart_button: Button = game_over_menu.get_node_or_null(
	"RestartButton"
) as Button if game_over_menu else null

@onready var pause_return_to_town_button: Button = get_tree().current_scene.get_node_or_null(
	"CanvasLayer/PauseMenu/CenterContainer/CenterVBox/ReturnToTownButton"
) as Button

@onready var return_to_town_button: Button = game_over_menu.get_node_or_null(
	"ReturnToTownButton"
) as Button if game_over_menu else null

@onready var kill_label: Label = get_tree().current_scene.get_node_or_null(
	"CanvasLayer/KillLabel"
) as Label




func _ready() -> void:
	super._ready()
	run_time_seconds = 0.0
	run_ended = false
	current_health = max_health
	dodge_energy = max_dodge_energy

	var sprite_node = get_node_or_null("CharacterSprite")
	if sprite_node is AnimatedSprite3D:
		sprite_node.play("default")

	# Keep the level-up sound playing while the game is paused.
	if level_up_sound:
		level_up_sound.process_mode = Node.PROCESS_MODE_ALWAYS

	# Find the AnimationPlayer automatically if not assigned in the Inspector.
	if animation_player == null:
		animation_player = find_child(
			"AnimationPlayer",
			true,
			false
		) as AnimationPlayer

	if animation_player != null:
		if not animation_player.animation_finished.is_connected(
			_on_animation_player_animation_finished
		):
			animation_player.animation_finished.connect(
				_on_animation_player_animation_finished
			)

		animation_player.speed_scale = 1.0

	# Initialize the health display.
	if health_label:
		health_label.text = "Health: %d / %d" % [
			current_health,
			max_health
		]
	# Initialize game-over controls.
	if game_over_menu:
		game_over_menu.hide()

	if restart_button:
		if not restart_button.pressed.is_connected(_on_restart_pressed):
			restart_button.pressed.connect(_on_restart_pressed)

	if return_to_town_button:
		if not return_to_town_button.pressed.is_connected(
			_on_return_to_town_pressed
		):
			return_to_town_button.pressed.connect(
				_on_return_to_town_pressed
			)

	if pause_return_to_town_button:
		if not pause_return_to_town_button.pressed.is_connected(
			_on_return_to_town_pressed
		):
			pause_return_to_town_button.pressed.connect(
				_on_return_to_town_pressed
			)

	# Initialize kill and XP displays.
	kill_count = 0

	if kill_label:
		kill_label.text = "Kills: 0"

	if xp_label:
		xp_label.text = "Level: %d | XP: %d / %d" % [
			player_level,
			current_xp,
			xp_to_level
		]

	# Start the selected visual's idle animation.
	if use_archer_animations:
		if archer_animation_player == null:
			push_warning("Archer animations enabled but no Archer AnimationPlayer assigned.")
		else:
			archer_animation_player.play(&"Idle")
	else:
		play_player_animation(&"gun_idle")

	# Preserve the developer admin panel.
	call_deferred("create_debug_admin_panel")





func take_damage(amount: int) -> void:
	var before_hp := current_health
	super.take_damage(amount)
	if current_health < before_hp:
		if hurt_sound:
			hurt_sound.play()
		if current_health <= 0:
			play_archer_action(&"Death", 0.0)
		else:
			play_archer_action(&"Hurt", 0.35)

func _physics_process(delta: float) -> void:
	if not run_ended:
		run_time_seconds += delta



	# Read WASD input.
	var input_dir := Vector2.ZERO

	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1.0

	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1.0

	if Input.is_key_pressed(KEY_W):
		input_dir.y -= 1.0

	if Input.is_key_pressed(KEY_S):
		input_dir.y += 1.0

	input_dir = input_dir.normalized()

	# Calculate movement directions relative to the camera.
	var forward := Vector3.FORWARD
	var right := Vector3.RIGHT

	if camera != null:
		forward = -camera.global_basis.z
		right = camera.global_basis.x

	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	var move_dir := right * input_dir.x + forward * -input_dir.y
	move_dir = move_dir.normalized()

	# Smoothly face the WASD movement direction (visual only).
	# Preserve the existing model's forward-axis convention.
	if move_dir.length_squared() > 0.001:
		var facing_visual := get_active_visual()
		if facing_visual != null:
			var target_yaw := atan2(-move_dir.x, -move_dir.z)
			facing_visual.rotation.y = lerp_angle(
				facing_visual.rotation.y,
				target_yaw,
				clampf(turn_speed * delta, 0.0, 1.0)
			)

	# Flip the sprite based on horizontal movement.
	if character_sprite != null and absf(move_dir.x) > 0.05:
		character_sprite.flip_h = move_dir.x < 0.0

	# Start a dodge when Space is pressed and cooldown is ready.
	if (
	Input.is_action_just_pressed("dodge")
	and not is_dodging
	and try_spend_dodge_energy()
):
		if move_dir.length_squared() > 0.001:
			dodge_direction = move_dir
		else:
			dodge_direction = -global_basis.z
			dodge_direction.y = 0.0
			dodge_direction = dodge_direction.normalized()

		is_dodging = true
		is_invulnerable = true
		dodge_timer = dodge_duration

		if get_active_visual() != null:
			dodge_start_visual_rotation_x = get_active_visual().rotation.x

	# Apply dodge movement or regular movement.
	if is_dodging:
		dodge_timer -= delta

		var progress := 1.0 - clampf(
			dodge_timer / maxf(dodge_duration, 0.001),
			0.0,
			1.0
		)

		# Visually tumble the active character model.
		if get_active_visual() != null:
			get_active_visual().rotation.x = (
				dodge_start_visual_rotation_x + progress * TAU
			)

		velocity.x = dodge_direction.x * dodge_speed
		velocity.z = dodge_direction.z * dodge_speed

		if dodge_timer <= 0.0:
			is_dodging = false
			is_invulnerable = false

			if get_active_visual() != null:
				get_active_visual().rotation.x = dodge_start_visual_rotation_x
	else:
		velocity.x = move_dir.x * move_speed
		velocity.z = move_dir.z * move_speed

	# Apply gravity and floor movement.
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
##TEST

	move_and_slide()


	# Select an animation, keeping one-shot archer actions from being interrupted.
	if use_archer_animations:
		archer_action_time = maxf(0.0, archer_action_time - delta)
		if archer_action_time <= 0.0:
			archer_action = &""
			update_archer_locomotion(input_dir)
	elif not is_dodging and fire_cooldown <= 0.0:
		update_player_animation(input_dir)

	# Automatic firing.
	fire_cooldown = maxf(0.0, fire_cooldown - delta)

	if fire_cooldown <= 0.0 and not run_ended:
		if auto_fire_enabled:
			var target_enemy: Node3D = find_nearest_auto_fire_target()

			if target_enemy != null:
				shoot_at_position(target_enemy.global_position)
				fire_cooldown = maxf(fire_rate, 0.01)

			elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				shoot()
				fire_cooldown = maxf(fire_rate, 0.01)




func _process(delta: float) -> void:
	if hurt_cooldown_remaining > 0.0:
		hurt_cooldown_remaining = maxf(
			0.0,
			hurt_cooldown_remaining - delta
		)

	if not is_dead and not run_ended:
		dodge_energy = minf(
			max_dodge_energy,
			dodge_energy + dodge_energy_regen * delta
		)

	if is_instance_valid(player_health_bar):
		if player_health_bar.has_method("set_dodge_energy"):
			player_health_bar.set_dodge_energy(
				dodge_energy,
				max_dodge_energy
			)



func find_nearest_auto_fire_target() -> Node3D:
	var nearest_enemy: Node3D = null
	var effective_range: float = Auto_fire_range * attack_range_multiplier
	var nearest_distance_squared: float = effective_range * effective_range

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node3D:
			continue

		if not is_instance_valid(enemy):
			continue

		if enemy.is_queued_for_deletion():
			continue

		var offset: Vector3 = enemy.global_position - global_position
		offset.y = 0.0
		var distance_squared: float = offset.length_squared()

		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_enemy = enemy

	return nearest_enemy

func shoot() -> void:
	if camera == null:
		return

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_direction: Vector3 = camera.project_ray_normal(mouse_pos)

	if absf(ray_direction.y) < 0.001:
		return

	var distance: float = -ray_origin.y / ray_direction.y

	if distance < 0.0:
		return

	var target: Vector3 = ray_origin + ray_direction * distance

	shoot_at_position(target)


func shoot_at_position(target: Vector3) -> void:
	var shot_origin: Vector3 = global_position + Vector3(0.0, 0.5, 0.0)

	var base_direction: Vector3 = target - shot_origin
	base_direction.y = 0.0

	if base_direction.length_squared() < 0.001:
		return

	base_direction = base_direction.normalized()

	if bow_sound != null:
		bow_sound.play()

	if use_archer_animations:
		play_archer_action(&"Attack", maxf(fire_rate, 0.01))

	# Play the bow animation at a speed matching the firing rate.
	if not use_archer_animations and animation_player != null:
		if animation_player.has_animation(&"Bow"):
			var desired_duration: float = maxf(fire_rate, 0.01)
			var bow_animation_duration: float = (
				animation_player.get_animation(&"Bow").length
			)
			var playback_speed: float = (
				bow_animation_duration / desired_duration
			)

			current_animation = &"Bow"
			animation_player.speed_scale = playback_speed
			animation_player.play(&"Bow")

	var spread_angle: float = 10.0
	var total_spread: float = spread_angle * float(multishot_count - 1)

	for i in range(multishot_count):
		var angle_offset: float = 0.0

		if multishot_count > 1:
			angle_offset = (
				-total_spread / 2.0
				+ spread_angle * float(i)
			)

		var shot_direction := base_direction.rotated(
			Vector3.UP,
			deg_to_rad(angle_offset)
		).normalized()

		var projectile = ProjectilePool.get_projectile()

		if projectile == null:
			continue
		var attack_tags: Array[String] = ["ranged", "projectile", "physical"]

		var hit_result: Dictionary = DamageCalculator.calculate_hit(
			projectile_damage + get_attack_damage_bonus(attack_tags),
			critical_hit_chance,
			critical_damage_multiplier,
			minimum_damage_multiplier,
			maximum_damage_multiplier
		)


		var final_damage:int = hit_result["damage"]
		var is_critical_hit: bool = hit_result["is_critical"]

		projectile.reset_projectile(
			shot_origin,
			shot_direction,
			final_damage,
			is_critical_hit,
			ricochet_stacks
		)


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"gun_shot":
		if animation_player != null:
			animation_player.speed_scale = 1.0

		current_animation = &""


func play_player_animation(animation_name: StringName) -> void:
	if animation_player == null:
		return

	if not animation_player.has_animation(animation_name):
		return

	if current_animation == animation_name:
		return

	current_animation = animation_name
	animation_player.play(animation_name)


func update_player_animation(input_dir: Vector2) -> void:
	if is_dodging:
		return

	# Play walk while moving, with run as a fallback.
	if input_dir.length_squared() > 0.001:
		if animation_player != null:
			if animation_player.has_animation(&"walk"):
				play_player_animation(&"walk")
				return

			if animation_player.has_animation(&"run"):
				play_player_animation(&"run")
				return

	# Return to the ready-to-shoot pose when stationary.
	play_player_animation(&"gun_idle")




# Optional Archer.tscn animation controller. Disable use_archer_animations to revert.
func get_active_visual() -> Node3D:
	return archer_visual if use_archer_animations and archer_visual != null else player_visual


func update_archer_locomotion(input_dir: Vector2) -> void:
	if archer_animation_player == null or current_health <= 0:
		return
	var desired: StringName = &"Run" if input_dir.length_squared() > 0.001 else &"Idle"
	if archer_animation_player.has_animation(desired) and archer_animation_player.current_animation != desired:
		archer_animation_player.speed_scale = 1.0
		archer_animation_player.play(desired)


func play_archer_action(name: StringName, fallback_duration: float) -> void:
	if not use_archer_animations or archer_animation_player == null:
		return
	if not archer_animation_player.has_animation(name):
		return
	archer_animation_player.speed_scale = 1.0
	archer_animation_player.play(name)
	archer_action = name
	archer_action_time = maxf(fallback_duration, archer_animation_player.get_animation(name).length)

func _on_return_to_town_pressed() -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree

	if scene_tree == null:
		push_error("Return to Town failed: SceneTree not available.")
		return

	scene_tree.paused = false
	scene_tree.call_deferred(
		"change_scene_to_file",
		"res://Scenes/Town.tscn"
	)







func die() -> void:
	show_game_over()

func show_game_over() -> void:
	if run_ended:
		return

	run_ended = true
	if death_sound:
		death_sound.process_mode = Node.PROCESS_MODE_ALWAYS
		death_sound.play()

	# Submit this run to the online leaderboard.
	var time_alive: int = floori(run_time_seconds)
	if PlayerService.player_name.strip_edges().is_empty():
		push_warning("Leaderboard: player username is empty!")
	else:
		LeaderboardService.submit_run(
			PlayerService.player_name,
			kill_count,
			player_level,
			time_alive,
			kill_count
		)

	# Find the game-over menu anywhere in the running scene tree.
	var found_game_over_menu := get_tree().root.find_child(
		"GameOverMenu",
		true,
		false
	) as Control

	if found_game_over_menu != null:
		found_game_over_menu.process_mode = Node.PROCESS_MODE_ALWAYS
		found_game_over_menu.show()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = true
	else:
		push_error(
			"GameOverMenu wasn't found. Make sure Game.tscn is loaded."
		)



func _on_restart_pressed() -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree

	if scene_tree == null:
		push_error("Restart failed: SceneTree not available.")
		return

	if scene_tree.current_scene == null:
		push_error("Restart failed: No current scene.")
		return

	scene_tree.paused = false
	scene_tree.call_deferred("reload_current_scene")


# DEVELOPER ADMIN PANEL

func create_debug_admin_panel() -> void:
	if not OS.has_feature("debug"):
		return

	if not is_inside_tree():
		return

	var tree := get_tree()
	if tree == null:
		return

	var current_scene := tree.current_scene
	if current_scene == null:
		return

	var admin_layer := CanvasLayer.new()
	admin_layer.name = "DebugAdminPanel"
	admin_layer.layer = 100
	admin_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	current_scene.add_child(admin_layer)

	var panel := Panel.new()
	panel.name = "AdminPanel"
	panel.position = Vector2(700, 400)
	panel.size = Vector2(520, 250)
	admin_layer.add_child(panel)

	admin_panel = panel
	admin_panel.hide()

	var title := Label.new()
	title.text = "DEV ADMIN PANEL"
	title.position = Vector2(20, 20)
	title.add_theme_font_size_override("font_size", 28)
	panel.add_child(title)

	admin_multishot_label = Label.new()
	admin_multishot_label.text = "Multishot: %d" % multishot_count
	admin_multishot_label.position = Vector2(20, 75)
	admin_multishot_label.add_theme_font_size_override("font_size", 22)
	panel.add_child(admin_multishot_label)

	var add_multishot_button := Button.new()
	add_multishot_button.text = "+20 MULTISHOT"
	add_multishot_button.position = Vector2(20, 120)
	add_multishot_button.size = Vector2(210, 45)
	add_multishot_button.add_theme_font_size_override("font_size", 20)
	add_multishot_button.pressed.connect(
		_on_debug_add_multishot_pressed
	)
	panel.add_child(add_multishot_button)

	admin_godmode_label = Label.new()
	admin_godmode_label.text = "Godmode: OFF"
	admin_godmode_label.position = Vector2(20, 175)
	admin_godmode_label.size = Vector2(200, 35)
	panel.add_child(admin_godmode_label)

	admin_godmode_button = Button.new()
	admin_godmode_button.text = "Enable Godmode"
	admin_godmode_button.position = Vector2(250, 170)
	admin_godmode_button.size = Vector2(220, 40)
	admin_godmode_button.pressed.connect(
		_on_debug_toggle_godmode_pressed
	)
	panel.add_child(admin_godmode_button)

	var training_dummy_button := Button.new()
	training_dummy_button.text = "Spawn Training Dummy"
	training_dummy_button.position = Vector2(20, 215)
	training_dummy_button.size = Vector2(220, 30)
	training_dummy_button.pressed.connect(
		_on_spawn_training_dummy_pressed
	)
	panel.add_child(training_dummy_button)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F2:
			fps_visible = not fps_visible
			update_fps_display()

	if not OS.has_feature("debug"):
		return

	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_F1:
			if admin_panel != null:
				admin_panel.visible = not admin_panel.visible
				get_viewport().set_input_as_handled()


func update_fps_display() -> void:
	if fps_label == null:
		return

	fps_label.visible = fps_visible

	if fps_visible:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


func _on_debug_add_multishot_pressed() -> void:
	if not OS.has_feature("editor"):
		return

	multishot_count += 20

	if admin_multishot_label:
		admin_multishot_label.text = "Multishot: %d" % multishot_count


func _on_debug_toggle_godmode_pressed() -> void:
	godmode_enabled = not godmode_enabled

	if godmode_enabled:
		admin_godmode_label.text = "Godmode: ON"
		admin_godmode_button.text = "Disable Godmode"
	else:
		admin_godmode_label.text = "Godmode: OFF"
		admin_godmode_button.text = "Enable Godmode"


func _on_spawn_training_dummy_pressed() -> void:
	var dummy := TRAINING_DUMMY_SCENE.instantiate() as Node3D

	if dummy == null:
		push_error("Failed to instantiate training_dummy.tscn")
		return

	get_tree().current_scene.add_child(dummy)

	# Spawn the training dummy three units in front of the player.
	dummy.global_position = global_position + (-global_basis.z * 3.0)

func face_cursor() -> void:
	if camera == null or player_visual == null:
		return

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_direction: Vector3 = camera.project_ray_normal(mouse_pos)

	# Find where the cursor ray intersects the ground plane.
	if absf(ray_direction.y) < 0.001:
		return

	var distance: float = -ray_origin.y / ray_direction.y
	if distance < 0.0:
		return

	var target: Vector3 = ray_origin + ray_direction * distance

	# Calculate a horizontal direction from the player to the cursor.
	var direction: Vector3 = target - global_position
	direction.y = 0.0

	if direction.length_squared() < 0.001:
		return

	direction = direction.normalized()

	player_visual.rotation.y = atan2(direction.x, direction.z)

	if character_sprite != null:
		character_sprite.flip_h = direction.x < 0.0

func update_sprite_facing() -> void:
	if character_sprite == null:
		return

	var horizontal_input := Input.get_axis("move_left", "move_right")

	if absf(horizontal_input) < 0.05:
		return

	character_sprite.flip_h = horizontal_input < 0.0


func update_player_health_bar_position() -> void:
	if not is_instance_valid(player_health_bar):
		return

	player_health_bar.show()

	var viewport_size := get_viewport().get_visible_rect().size
	var bar_size := player_health_bar.size * player_health_bar.scale

	player_health_bar.position = Vector2(
		(viewport_size.x - bar_size.x) * 0.5,
		viewport_size.y - bar_size.y - 30.0
	)

func set_player_level(level: int) -> void:
	if player_health_bar:
		player_health_bar.set_player_level(player_level)

func upgrade_critical_strike() -> void:
	critical_hit_chance = minf(critical_hit_chance + 0.05, 1.0)


# Range indicator shows AUTO-TARGET ACQUISITION range, not maximum arrow travel.
func get_basic_attack_range() -> float:
	return Auto_fire_range * attack_range_multiplier

func is_basic_range_indicator_applicable() -> bool:
	return auto_fire_enabled

func try_spend_dodge_energy() -> bool:
	if dodge_energy < dodge_energy_cost:
		return false

	dodge_energy -= dodge_energy_cost
	return true


func get_dodge_energy_percent() -> float:
	return clampf(
		dodge_energy / maxf(max_dodge_energy, 1.0),
		0.0,
		1.0
	)
