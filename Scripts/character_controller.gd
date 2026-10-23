extends "res://Scripts/player_base.gd"
## Attach this script to the root CharacterBody3D of every playable character.
## Movement, melee, projectile firing, animation bindings and run lifecycle are
## shared. Starting values and combat style come from CharacterBalance .tres.
## XP, HUD, health, BladeFlurry, RangeIndicator and upgrades stay in player_base.

@export_group("Character Configuration")
@export var balance_profile: CharacterBalance

@export_group("Visual / Animation Bindings")
@export var visual_root: Node3D
@export var animation_player: AnimationPlayer
@export var character_sprite: AnimatedSprite3D
@export var rotate_visual_on_dodge: bool = true

# These properties are retained at runtime for existing upgrade cards, abilities,
# range indicators, tests and external scripts. Change starting stats in .tres.
var acceleration: float = 30.0
var rotation_speed: float = 10.0
var turn_speed: float = 10.0
var melee_damage: int = 10
var melee_windup: float = 0.25
var melee_attack_angle: float = 90.0
var attack_speed: float = 1.0
var attack_interval: float = 0.40
var auto_attack_range: float = 5.0
var Auto_fire_range: float = 15.0
var auto_attack_enabled: bool = true
var auto_fire_enabled: bool = true
var critical_hit_chance: float = 0.05
var critical_damage_multiplier: float = 2.0
var minimum_damage_multiplier: float = 0.80
var maximum_damage_multiplier: float = 1.20

var is_attacking: bool = false
var is_dodging: bool = false
var dodge_timer: float = 0.0
var dodge_start_visual_rotation_x: float = 0.0
var attack_cooldown: float = 0.0
var fire_cooldown: float = 0.0
var melee_elapsed: float = 0.0
var melee_hit_applied: bool = false
var attack_tracking_target: Node3D
var melee_aim_angle: float = 0.0
var action_time_remaining: float = 0.0
var melee_action_remaining: float = 0.0
var last_animation: StringName = &""
var _last_synced_attack_interval: float = 0.40
var _bow_sound: AudioStreamPlayer3D
var _hurt_sound: AudioStreamPlayer3D
var _death_sound: AudioStreamPlayer

func _ready() -> void:
	# Hide the Windows cursor while keeping mouse movement active.
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	# Apply defaults BEFORE player_base._ready() initializes health, XP and HUD.
	_apply_starting_balance()
	super._ready()

	_bow_sound = get_node_or_null("BowSound") as AudioStreamPlayer3D
	_hurt_sound = get_node_or_null("HurtSound") as AudioStreamPlayer3D
	_death_sound = get_node_or_null("DeathSound") as AudioStreamPlayer

	if visual_root == null:
		visual_root = get_node_or_null("CharacterModel") as Node3D
	if visual_root == null:
		visual_root = get_node_or_null("Billjamin_Archer_V5") as Node3D

	if animation_player == null and visual_root != null:
		animation_player = visual_root.find_child("AnimationPlayer", true, false) as AnimationPlayer

	if character_sprite == null:
		character_sprite = get_node_or_null("CharacterSprite") as AnimatedSprite3D
	if character_sprite == null:
		character_sprite = get_node_or_null("CharacterVisual") as AnimatedSprite3D

	if animation_player != null:
		if not animation_player.animation_finished.is_connected(_on_character_animation_finished):
			animation_player.animation_finished.connect(_on_character_animation_finished)

	if _death_sound != null:
		_death_sound.process_mode = Node.PROCESS_MODE_ALWAYS

	var level_up_audio := get_node_or_null("LevelUpSound") as AudioStreamPlayer
	if level_up_audio != null:
		level_up_audio.process_mode = Node.PROCESS_MODE_ALWAYS

	var game_over_menu: Control = null
	if get_tree().current_scene != null:
		game_over_menu = get_tree().current_scene.find_child("GameOverMenu", true, false) as Control

	if game_over_menu != null:
		game_over_menu.hide()

	_connect_menu_buttons()
	_play_animation(_animation_name("idle_animation", &"Idle"), 1.0, true)

func _apply_starting_balance() -> void:
	if balance_profile == null:
		push_warning("Character controller has no balance profile; using default runtime values.")
		return
	var b := balance_profile
	move_speed = b.move_speed
	acceleration = b.acceleration
	rotation_speed = b.turn_speed
	turn_speed = b.turn_speed
	gravity = b.gravity
	max_health = b.max_health
	contact_damage_cooldown = b.contact_damage_cooldown
	dodge_speed = b.dodge_speed
	dodge_duration = b.dodge_duration
	max_dodge_energy = b.max_dodge_energy
	dodge_energy_cost = b.dodge_energy_cost
	dodge_energy_regen = b.dodge_energy_regen
	projectile_damage = b.starting_damage
	melee_damage = b.starting_damage
	fire_rate = b.attack_interval
	attack_interval = b.attack_interval
	_last_synced_attack_interval = b.attack_interval
	auto_attack_range = b.attack_range
	Auto_fire_range = b.attack_range
	auto_fire_enabled = b.auto_attack_enabled
	auto_attack_enabled = b.auto_attack_enabled
	attack_speed = b.attack_animation_speed
	melee_windup = b.melee_windup
	melee_attack_angle = b.melee_attack_angle
	critical_hit_chance = b.critical_hit_chance
	critical_damage_multiplier = b.critical_damage_multiplier
	minimum_damage_multiplier = b.minimum_damage_multiplier
	maximum_damage_multiplier = b.maximum_damage_multiplier
	xp_to_level = b.xp_to_level
	xp_multiplier = b.xp_multiplier
	blade_flurry_damage = b.blade_flurry_damage
	blade_flurry_radius = b.blade_flurry_radius
	blade_flurry_cooldown = b.blade_flurry_cooldown
	blade_flurry_damage_per_milestone = b.blade_flurry_damage_per_milestone

func _is_melee() -> bool:
	return balance_profile != null and balance_profile.combat_style == CharacterBalance.CombatStyle.MELEE

func _animation_name(field: String, fallback: StringName) -> StringName:
	if balance_profile == null:
		return fallback
	return StringName(balance_profile.get(field))

func _physics_process(delta: float) -> void:
	if is_dead or run_ended:
		return
	run_time_seconds += delta
	_sync_attack_interval()
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	fire_cooldown = attack_cooldown
	action_time_remaining = maxf(action_time_remaining - delta, 0.0)
	var direction: Vector3 = _movement_direction()
	_handle_dodge_and_movement(direction, delta)
	_update_facing(direction, delta)
	if _is_melee():
		_update_melee_attack(delta)
		_update_melee_auto_attack()
	else:
		_update_projectile_attack()
	_update_character_animation(direction)

# Both old stat names remain upgrade-compatible. Synchronize whichever changed
# since the previous physics frame (Rapid Fire uses attack_interval; some .tres
# upgrades may still target fire_rate).
func _sync_attack_interval() -> void:
	if not is_equal_approx(attack_interval, _last_synced_attack_interval):
		fire_rate = attack_interval
	elif not is_equal_approx(fire_rate, _last_synced_attack_interval):
		attack_interval = fire_rate
	attack_interval = maxf(attack_interval, 0.01)
	fire_rate = attack_interval
	_last_synced_attack_interval = attack_interval

func _movement_direction() -> Vector3:
	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A): input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D): input_dir.x += 1.0
	if Input.is_key_pressed(KEY_W): input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S): input_dir.y += 1.0
	input_dir = input_dir.normalized()
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3(input_dir.x, 0.0, input_dir.y)
	var forward := -cam.global_basis.z
	var right := cam.global_basis.x
	forward.y = 0.0
	right.y = 0.0
	return (right.normalized() * input_dir.x - forward.normalized() * input_dir.y).normalized()

func _input(event: InputEvent) -> void:
	if is_dead or run_ended:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.is_action_pressed("dodge"):
			_start_dodge()

func _start_dodge() -> void:
	if is_dodging or not try_spend_dodge_energy():
		return
	var direction := _movement_direction()
	if direction.length_squared() < 0.01:
		if visual_root != null:
			direction = -visual_root.global_basis.z
		else:
			direction = -global_basis.z
		direction.y = 0.0
		direction = direction.normalized()
	dodge_direction = direction
	dodge_timer = maxf(dodge_duration, 0.01)
	dodge_time_remaining = dodge_timer
	is_dodging = true
	is_invulnerable = true
	if visual_root != null:
		dodge_start_visual_rotation_x = visual_root.rotation.x

func _handle_dodge_and_movement(direction: Vector3, delta: float) -> void:
	if is_dodging:
		dodge_timer -= delta
		dodge_time_remaining = maxf(dodge_timer, 0.0)
		velocity.x = dodge_direction.x * dodge_speed
		velocity.z = dodge_direction.z * dodge_speed
		if visual_root != null and balance_profile != null and balance_profile.dodge_visual_spin and rotate_visual_on_dodge:
			var progress := 1.0 - clampf(dodge_timer / maxf(dodge_duration, 0.001), 0.0, 1.0)
			visual_root.rotation.x = dodge_start_visual_rotation_x + progress * TAU
		if dodge_timer <= 0.0:
			is_dodging = false
			is_invulnerable = false
			if visual_root != null:
				visual_root.rotation.x = dodge_start_visual_rotation_x
	else:
		var desired := direction * move_speed
		if acceleration <= 0.0:
			velocity.x = desired.x
			velocity.z = desired.z
		else:
			velocity.x = move_toward(velocity.x, desired.x, acceleration * delta)
			velocity.z = move_toward(velocity.z, desired.z, acceleration * delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()

func _update_facing(direction: Vector3, delta: float) -> void:
	if visual_root == null or is_dodging:
		return
	if _is_melee() and is_attacking:
		return
	if direction.length_squared() > 0.001:
		var facing_offset := PI if _is_melee() else 0.0
		var target_angle := atan2(-direction.x, -direction.z) + facing_offset
		visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_angle, clampf(turn_speed * delta, 0.0, 1.0))
	if character_sprite != null and absf(direction.x) > 0.05:
		character_sprite.flip_h = direction.x < 0.0

func _update_character_animation(direction: Vector3) -> void:
	if animation_player == null or is_dead or run_ended:
		return
	if _is_melee() and is_attacking:
		return
	if not _is_melee() and action_time_remaining > 0.0:
		return
	if is_dodging:
		return
	var moving: bool = direction.length_squared() > 0.001
	var name := _animation_name("run_animation", &"Run") if moving else _animation_name("idle_animation", &"Idle")
	if not animation_player.has_animation(name):
		# Imported rigs sometimes use lowercase walk/run instead of Run.
		name = &"walk" if moving else &"gun_idle"
	_play_animation(name)

func _play_animation(name: StringName, speed: float = 1.0, force: bool = false) -> void:
	if animation_player == null or not animation_player.has_animation(name):
		return
	if not force and animation_player.current_animation == name and animation_player.is_playing():
		return
	last_animation = name
	animation_player.speed_scale = 1.0
	animation_player.play(name, -1.0, maxf(speed, 0.01))

func _on_character_animation_finished(name: StringName) -> void:
	if _is_melee() and name == _animation_name("attack_animation", &"Dagger_Attack"):
		if melee_hit_applied:
			is_attacking = false
			attack_tracking_target = null
	if not _is_melee() and name == _animation_name("attack_animation", &"Attack"):
		action_time_remaining = 0.0

func _find_nearest_enemy(max_range: float) -> Node3D:
	var nearest: Node3D
	var best_distance_sq := max_range * max_range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node3D or not is_instance_valid(enemy):
			continue
		if enemy.is_queued_for_deletion():
			continue
		var offset: Vector3 = enemy.global_position - global_position
		offset.y = 0.0
		var distance_sq := offset.length_squared()
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			nearest = enemy
	return nearest

func get_basic_attack_range() -> float:
	var base_range: float = auto_attack_range if _is_melee() else Auto_fire_range
	return base_range * attack_range_multiplier

func is_basic_range_indicator_applicable() -> bool:
	return auto_attack_enabled if _is_melee() else auto_fire_enabled

func _get_cursor_world_position() -> Variant:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := cam.project_ray_origin(mouse_position)
	var ray_direction := cam.project_ray_normal(mouse_position)
	var ground_plane := Plane(Vector3.UP, global_position.y)
	return ground_plane.intersects_ray(ray_origin, ray_direction)

# MELEE: original Rogue auto-targeting and cone damage.
func _update_melee_auto_attack() -> void:
	if not auto_attack_enabled or is_attacking or attack_cooldown > 0.0:
		return
	var target := _find_nearest_enemy(get_basic_attack_range())
	if target == null:
		return
	var combat_settings := get_node_or_null("/root/CombatSettings")
	var use_auto_targeting: bool = true
	if combat_settings != null:
		use_auto_targeting = bool(combat_settings.get("auto_targeting_enabled"))
	if use_auto_targeting:
		attack_tracking_target = target
		_start_melee_at(target.global_position)
	else:
		attack_tracking_target = null
		var cursor_position: Variant = _get_cursor_world_position()
		if cursor_position != null:
			_start_melee_at(cursor_position)

func _start_melee_at(target_position: Vector3) -> void:
	if is_attacking:
		return
	is_attacking = true
	melee_elapsed = 0.0
	melee_hit_applied = false
	attack_cooldown = maxf(attack_interval, 0.01)
	var direction := target_position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		melee_aim_angle = atan2(-direction.x, -direction.z)
		if visual_root != null:
			visual_root.rotation.y = melee_aim_angle + PI
	var attack_anim := _animation_name("attack_animation", &"Dagger_Attack")
	melee_action_remaining = maxf(melee_windup, 0.01)
	if animation_player != null and animation_player.has_animation(attack_anim):
		melee_action_remaining = maxf(melee_action_remaining, animation_player.get_animation(attack_anim).length / maxf(attack_speed, 0.01))
	_play_animation(attack_anim, attack_speed, true)
	# Safety fallback also handles a missing or looping imported animation.

func _update_melee_attack(delta: float) -> void:
	if not is_attacking:
		return
	melee_action_remaining = maxf(melee_action_remaining - delta, 0.0)
	if not melee_hit_applied:
		if balance_profile != null and balance_profile.follow_target_during_windup:
			if is_instance_valid(attack_tracking_target) and not attack_tracking_target.is_queued_for_deletion():
				var direction: Vector3 = attack_tracking_target.global_position - global_position
				direction.y = 0.0
				if direction.length_squared() > 0.001:
					melee_aim_angle = atan2(-direction.x, -direction.z)
					if visual_root != null:
						visual_root.rotation.y = melee_aim_angle + PI
		melee_elapsed += delta
		if melee_elapsed >= maxf(melee_windup, 0.01):
			melee_hit_applied = true
			_apply_melee_damage()
			CombatVisualManager.player_slash(global_position, get_basic_attack_range(), melee_aim_angle, melee_attack_angle)
			attack_tracking_target = null
	# Prevent getting stuck if the imported animation loops or never emits finished.
	if melee_hit_applied and melee_action_remaining <= 0.0:
		is_attacking = false

func _apply_melee_damage() -> void:
	var attack_direction := Vector3(-sin(melee_aim_angle), 0.0, -cos(melee_aim_angle))
	var range_sq := pow(get_basic_attack_range(), 2.0)
	var half_angle := deg_to_rad(melee_attack_angle * 0.5)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node3D or enemy.is_queued_for_deletion():
			continue
		var direction: Vector3 = enemy.global_position - global_position
		direction.y = 0.0
		var distance_sq := direction.length_squared()
		if distance_sq > range_sq or distance_sq < 0.0001:
			continue
		if attack_direction.angle_to(direction.normalized()) > half_angle:
			continue
		var hit: Dictionary = DamageCalculator.calculate_hit(melee_damage, critical_hit_chance, critical_damage_multiplier, minimum_damage_multiplier, maximum_damage_multiplier)
		if enemy.has_method("take_projectile_hit"):
			enemy.call("take_projectile_hit", int(hit["damage"]), bool(hit["is_critical"]))
		elif enemy.has_method("take_damage"):
			enemy.call("take_damage", int(hit["damage"]))

# PROJECTILE: original Archer targeting, multishot, critical hits and pooling.
func _update_projectile_attack() -> void:
	if attack_cooldown > 0.0:
		return
	if auto_fire_enabled:
		var target := find_nearest_auto_fire_target()
		if target != null:
			shoot_at_position(target.global_position)
			return
	if balance_profile == null or balance_profile.manual_attack_enabled:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			shoot()

func find_nearest_auto_fire_target() -> Node3D:
	return _find_nearest_enemy(get_basic_attack_range())

func shoot() -> void:
	var position: Variant = _get_cursor_world_position()
	if position != null:
		shoot_at_position(position)

func shoot_at_position(target: Vector3) -> void:
	if is_dead or run_ended:
		return
	var height: float = balance_profile.projectile_height if balance_profile != null else 0.5
	var origin := global_position + Vector3(0.0, height, 0.0)
	var base_direction: Vector3 = target - origin
	base_direction.y = 0.0
	if base_direction.length_squared() < 0.001:
		return
	base_direction = base_direction.normalized()
	attack_cooldown = maxf(attack_interval, 0.01)
	fire_cooldown = attack_cooldown
	if _bow_sound != null:
		_bow_sound.play()
	var anim_name := _animation_name("attack_animation", &"Attack")
	if animation_player != null and animation_player.has_animation(anim_name):
		var animation_duration: float = animation_player.get_animation(anim_name).length
		var playback_speed: float = attack_speed
		if animation_duration > 0.0:
			playback_speed = animation_duration / maxf(attack_interval, 0.01)
		_play_animation(anim_name, playback_speed, true)
		action_time_remaining = maxf(attack_interval, 0.01)
	var spread: float = balance_profile.multishot_spread_degrees if balance_profile != null else 10.0
	var total_spread: float = spread * float(multishot_count - 1)
	for i in range(multishot_count):
		var angle_offset: float = spread * float(i) - total_spread * 0.5
		var direction := base_direction.rotated(Vector3.UP, deg_to_rad(angle_offset)).normalized()
		var projectile = ProjectilePool.get_projectile()
		if projectile == null:
			continue
		var tags: Array[String] = ["ranged", "projectile", "physical"]
		var hit: Dictionary = DamageCalculator.calculate_hit(projectile_damage + get_attack_damage_bonus(tags), critical_hit_chance, critical_damage_multiplier, minimum_damage_multiplier, maximum_damage_multiplier)
		projectile.reset_projectile(origin, direction, int(hit["damage"]), bool(hit["is_critical"]), ricochet_stacks)

func take_damage(amount: int) -> void:
	var previous_hp: int = current_health
	super.take_damage(amount)
	if current_health >= previous_hp:
		return
	if _hurt_sound != null:
		_hurt_sound.play()
	if current_health > 0:
		var hurt_anim := _animation_name("hurt_animation", &"Hurt")
		if animation_player != null and animation_player.has_animation(hurt_anim):
			_play_animation(hurt_anim, 1.0, true)
			action_time_remaining = animation_player.get_animation(hurt_anim).length

func upgrade_critical_strike() -> void:
	critical_hit_chance = minf(critical_hit_chance + 0.05, 1.0)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	is_attacking = false
	is_invulnerable = false
	velocity = Vector3.ZERO
	if _death_sound != null:
		_death_sound.play()
	if balance_profile != null and balance_profile.submit_leaderboard_on_death:
		if PlayerService.player_name.strip_edges() != "":
			LeaderboardService.submit_run(PlayerService.player_name, kill_count, player_level, floori(run_time_seconds), kill_count)
	# Existing base controls GameOverMenu, mouse mode and pausing.
	super.die()

func _connect_menu_buttons() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	for node in root.find_children("RestartButton", "Button", true, false):
		var restart := node as Button
		if restart != null and not restart.pressed.is_connected(_on_restart_pressed):
			restart.pressed.connect(_on_restart_pressed)
	for node in root.find_children("ReturnToTownButton", "Button", true, false):
		var town := node as Button
		if town != null and not town.pressed.is_connected(_on_return_to_town_pressed):
			town.pressed.connect(_on_return_to_town_pressed)

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().call_deferred("reload_current_scene")

func _on_return_to_town_pressed() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return

	tree.paused = false
	tree.call_deferred("change_scene_to_file", "res://Scenes/Town.tscn")

# Compatibility entry points retained for existing animation, HUD and ability code.
func get_active_visual() -> Node3D:
	return visual_root

func set_player_level(_level: int) -> void:
	if is_instance_valid(player_health_bar):
		player_health_bar.set_player_level(player_level)

func update_player_health_bar_position() -> void:
	if not is_instance_valid(player_health_bar):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var bar_size := player_health_bar.size * player_health_bar.scale
	player_health_bar.position = Vector2((viewport_size.x - bar_size.x) * 0.5, viewport_size.y - bar_size.y - 30.0)

func face_cursor() -> void:
	var position: Variant = _get_cursor_world_position()
	if position == null or visual_root == null:
		return
	var direction: Vector3 = position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		visual_root.rotation.y = atan2(direction.x, direction.z)

func update_sprite_facing() -> void:
	if character_sprite == null:
		return
	var horizontal_input := Input.get_axis("move_left", "move_right")
	if absf(horizontal_input) > 0.05:
		character_sprite.flip_h = horizontal_input < 0.0
