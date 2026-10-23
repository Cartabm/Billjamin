
extends CharacterBody3D
signal dungeon_enemy_killed(enemy: CharacterBody3D)

enum EnemyAIBehavior {
	CHASER,
	CHARGER,
	STALKER,
	BRUTE
}

@export var enemy_behavior: EnemyAIBehavior = EnemyAIBehavior.CHASER

# General enemy settings
@export var move_speed: float = 3.0
@export var gravity: float = 20.0
@export var max_health: int = 30
@export var arena_half_size: float = 9.0
@export var contact_damage: int = 50
@export var contact_damage_cooldown: float = 0.5
@export_range(0.0, 0.2, 0.005) var contact_hitbox_padding: float = 0.06
@export var magnet_drop_chance: float = 0.01

@export_group("Run Currency Drops")
@export_range(0.0, 1.0, 0.01) var currency_drop_chance: float = 0.25
@export var currency_min_drop: int = 5
@export var currency_max_drop: int = 15
@export_range(0.0, 1.0, 0.01) var elite_currency_drop_chance: float = 0.75
@export var elite_currency_min_drop: int = 15
@export var elite_currency_max_drop: int = 35

# Charger settings
@export var charger_cooldown: float = 3.5
@export var charger_windup: float = 0.8
@export var charger_rush_speed: float = 9.0
@export var charger_rush_duration: float = 0.65
@export var charger_punch_range: float = 1.5
@export var charger_punch_damage: int = 50
@export var charger_recovery: float = 0.8

# Stalker settings
@export var stalker_orbit_speed: float = 2.7
@export var stalker_orbit_radius: float = 3.0
@export var stalker_orbit_radius_tolerance: float = 0.6
@export var stalker_lunge_interval: float = 2.8
@export var stalker_lunge_windup: float = 0.45
@export var stalker_lunge_speed: float = 7.0
@export var stalker_lunge_duration: float = 0.45
@export var stalker_attack_range: float = 1.5
@export var stalker_attack_damage: int = 35
@export var stalker_retreat_speed: float = 4.0
@export var stalker_retreat_duration: float = 0.7
@export var stalker_reposition_duration: float = 0.5


# Brute settings
@export var brute_move_speed: float = 1.6
@export var brute_attack_cooldown: float = 2.5
@export var brute_windup_duration: float = 1.0
@export var brute_attack_range: float = 1.8
@export var brute_attack_damage: int = 65
@export var brute_recovery_duration: float = 1.2
@export var brute_attack_animation_duration: float = 0.7

# Elite Settings

@export_group("Elite Enemies")
@export_range(0.0, 1.0) var elite_chance: float = 0.08
@export var elite_scale: float = 1.15
@export var elite_health_multiplier: float = 2.0
@export var elite_damage_multiplier: float = 1.25
@export var elite_bonus_xp: int = 5
@export var elite_ring_height: float = 0.06
@export var elite_ring_radius: float = 0.8
@export var elite_pulse_speed: float = 3.0

enum EliteModifier {
	NONE,
	SWIFT,
	ARMORED,
	VOLATILE,
	COMMANDER
}

var is_elite: bool = false
var elite_modifier: EliteModifier = EliteModifier.NONE
var elite_ring: MeshInstance3D
var elite_ring_material: StandardMaterial3D
var elite_visuals: Node3D
var elite_visual_base_scale: Vector3 = Vector3.ONE
var elite_animation_time: float = 0.0
var elite_base_speed: float = 0.0
var elite_base_health: int = 0
var elite_bonus_xp_awarded: bool = false

var cached_player_position: Vector3 = Vector3.ZERO
var player_position_refresh_timer: float = 0.0

const PLAYER_POSITION_REFRESH_INTERVAL: float = 0.1



var contact_damage_timer: float = 0.0
var contact_damage_area: Area3D = null
var health: int
var base_health: int
var player: CharacterBody3D

var current_animation: StringName = &""

# Charger state
var charger_cooldown_timer: float = 2.0
var charger_state: StringName = &"approach"
var charger_state_timer: float = 0.0
var charger_direction: Vector3 = Vector3.ZERO
var charger_punch_damage_applied: bool = false

# Stalker state
var stalker_state: StringName = &"orbit"
var stalker_state_timer: float = 0.0
var stalker_lunge_cooldown_timer: float = 1.5
var stalker_lunge_direction: Vector3 = Vector3.ZERO
var stalker_orbit_direction: float = 1.0
var stalker_attack_damage_applied: bool = false
var stalker_retreat_direction: Vector3 = Vector3.ZERO

# Brute state
var brute_state: StringName = &"approach"
var brute_state_timer: float = 0.0
var brute_attack_cooldown_timer: float = 1.5
var brute_attack_damage_applied: bool = false


@onready var monster_animation: AnimationPlayer = find_animation_player()
@onready var enemy_sprite: AnimatedSprite3D = get_node_or_null("EnemySprite")
# Static visuals and lightweight movement bounce
var visual_root: Node3D
var visual_base_position: Vector3 = Vector3.ZERO
var bounce_time: float = 0.0

const WALK_BOUNCE_HEIGHT: float = 0.045
const WALK_BOUNCE_SPEED: float = 8.0
const ATTACK_BOUNCE_HEIGHT: float = 0.075
const ATTACK_BOUNCE_SPEED: float = 15.0

var stalker_next_attack: StringName = &"Attack01"
var sprite_animation_playing: StringName = &""
var hurt_animation_timer: float = 0.0
var is_dying: bool = false

const XP_GEM_SCENE = preload("res://Scenes/xp_gem.tscn")
const MAGNET_SCENE = preload("res://Scenes/MagnetPickup.tscn")
const CURRENCY_PICKUP_SCRIPT = preload("res://Scripts/CurrencyPickup.gd")
const DAMAGE_NUMBER_SCENE = preload("res://Scenes/DamageNumber.tscn")





func find_animation_player() -> AnimationPlayer:
	if enemy_behavior == EnemyAIBehavior.STALKER:
		var stalker_player := get_node_or_null(
			"MonsterVisual/BlueDemon2/AnimationPlayer"
		) as AnimationPlayer
		if stalker_player != null:
			return stalker_player

	elif enemy_behavior == EnemyAIBehavior.CHASER:
		var chaser_player := get_node_or_null(
			"MonsterVisual/Ninja2/AnimationPlayer"
		) as AnimationPlayer
		if chaser_player != null:
			return chaser_player

	elif enemy_behavior == EnemyAIBehavior.BRUTE:
		var brute_player := get_node_or_null(
			"MonsterVisual/MushroomKing2/AnimationPlayer"
		) as AnimationPlayer
		if brute_player != null:
			return brute_player


	elif enemy_behavior == EnemyAIBehavior.CHARGER:
		var charger_player := get_node_or_null(
			"MonsterVisual/Orc2/AnimationPlayer"
		) as AnimationPlayer
		if charger_player != null:
			return charger_player


	return find_child("AnimationPlayer", true, false) as AnimationPlayer





func _ready() -> void:
	add_to_group("enemies")
	# Enemies are on layer 2 and collide with the floor on layer 1.
# Enemies belong to physics layer 2.
	collision_layer = 2

# Collide with layers 1, 2, and 3.
# Layer 3 contains the procedural Overworld terrain.
	collision_mask = 7

	var scene_root := get_tree().current_scene
	var manager: Node = null

	if scene_root != null:
		manager = scene_root.find_child("HordeManager", true, false)

	if manager != null and manager.has_method("register_enemy"):
		manager.register_enemy(self)
		set_physics_process(false)
		print("Enemy registered with HordeManager: ", name)
	else:
		# No HordeManager in this scene.
		# Use the enemy's own physics processing instead.
		set_physics_process(true)
		print("Enemy using standalone physics: ", name)

	# Remove the health bar entirely.
	var health_bar := get_node_or_null("HealthBar")
	if health_bar != null:
		health_bar.queue_free()

	# Match the contact detector to the existing physics body once at spawn.
	# This does not change movement or floor collisions.
	_setup_contact_damage_area()

	base_health = max_health
	find_player()
	health = max_health


	if randf() < elite_chance:
		_make_elite()

	# Bounce the visible model/sprite, not the physics body.
	visual_root = get_node_or_null("MonsterVisual") as Node3D
	if visual_root == null:
		visual_root = enemy_sprite

	if visual_root != null:
		visual_base_position = visual_root.position

	_freeze_enemy_visuals()

	# Only elite enemies need per-frame visual processing.
	set_process(is_elite)

# Contact hitbox: a small padded copy of the enemy's movement collider.
# It is deliberately separate from the body's physical collision shape.
func _setup_contact_damage_area() -> void:
	var body_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if body_shape == null:
		push_warning("Missing body CollisionShape3D on " + name)
		return

	# Automatically add the component for future enemies that use this script.
	contact_damage_area = get_node_or_null("ContactDamageArea") as Area3D
	if contact_damage_area == null:
		contact_damage_area = Area3D.new()
		contact_damage_area.name = "ContactDamageArea"
		add_child(contact_damage_area)

	var contact_shape := contact_damage_area.get_node_or_null("ContactShape") as CollisionShape3D
	if contact_shape == null:
		contact_shape = CollisionShape3D.new()
		contact_shape.name = "ContactShape"
		contact_damage_area.add_child(contact_shape)

	if body_shape.shape == null:
		push_warning("Enemy body has no collision shape: " + name)
		return

	contact_damage_area.collision_layer = 0
	contact_damage_area.collision_mask = 1 # Player body uses physics layer 1.
	contact_damage_area.monitoring = true
	contact_damage_area.monitorable = true

	# Duplicate the resource so adjusting contact size cannot change movement.
	var new_shape := body_shape.shape.duplicate(true) as Shape3D
	var pad := maxf(contact_hitbox_padding, 0.0)

	if new_shape is CapsuleShape3D:
		var capsule := new_shape as CapsuleShape3D
		capsule.radius += pad
		capsule.height = maxf(capsule.height + pad * 2.0, capsule.radius * 2.0)
	elif new_shape is CylinderShape3D:
		var cylinder := new_shape as CylinderShape3D
		cylinder.radius += pad
		cylinder.height += pad * 2.0
	elif new_shape is BoxShape3D:
		var box_shape := new_shape as BoxShape3D
		box_shape.size += Vector3.ONE * (pad * 2.0)

	contact_shape.shape = new_shape
	# Both shapes are children of the same enemy root through an untransformed Area3D.
	contact_damage_area.transform = Transform3D.IDENTITY
	contact_shape.transform = body_shape.transform
	contact_shape.disabled = false


# Godot maintains this overlap list in the physics engine.
# A tiny padding makes contact register when solid bodies touch, since
# CharacterBody3D colliders normally prevent deep penetration.
func _player_is_in_contact() -> bool:
	if contact_damage_area == null or not is_instance_valid(player):
		return false

	for body in contact_damage_area.get_overlapping_bodies():
		if body == player and body.is_in_group("player"):
			return true

	return false


func _freeze_enemy_visuals() -> void:
	# Freeze AnimatedSprite3D on a single frame.
	if enemy_sprite != null and enemy_sprite.sprite_frames != null:
		var frames := enemy_sprite.sprite_frames
		var chosen_animation: StringName = &""

		if frames.has_animation(&"Idle"):
			chosen_animation = &"Idle"
		else:
			var animations := frames.get_animation_names()
			if not animations.is_empty():
				chosen_animation = animations[0]

		if chosen_animation != &"":
			enemy_sprite.animation = chosen_animation
			enemy_sprite.frame = 0
			enemy_sprite.stop()

	# Freeze the 3D model's AnimationPlayer on the first idle frame.
	if monster_animation != null:
		if monster_animation.has_animation(&"Idle"):
			monster_animation.play(&"Idle")
			monster_animation.seek(0.0, true)
			monster_animation.pause()
		else:
			monster_animation.stop()




func find_player() -> void:
	var scene := get_tree().current_scene

	if scene != null:
		player = scene.get_node_or_null("Player") as CharacterBody3D

		if player == null:
			player = scene.get_node_or_null("TestPlayer") as CharacterBody3D

	if player == null:
		var players := get_tree().get_nodes_in_group("player")

		for candidate in players:
			if candidate is CharacterBody3D:
				player = candidate
				break






func _physics_process(delta: float) -> void:
	_horde_step(delta)


func _horde_step(delta: float) -> void:
	if is_dying:
		return

	if player == null or not is_instance_valid(player):
		find_player()

	if player == null:
		velocity.x = 0.0
		velocity.z = 0.0

		velocity.y = 0.0

		_horde_move(delta)
		update_monster_animation()
		_update_cached_player_position(delta)
		return

	if enemy_behavior == EnemyAIBehavior.CHARGER:
		_process_charger(delta)
		return

	if enemy_behavior == EnemyAIBehavior.STALKER:
		_process_stalker(delta)
		update_sprite_facing()
		return

	if enemy_behavior == EnemyAIBehavior.BRUTE:
		_process_brute(delta)
		return

	# Chaser is the default behavior.
	_process_chaser(delta)

func _process(delta: float) -> void:
	if is_elite:
		_process_elite_visuals(delta)

	_update_visual_bounce(delta)


func _process_chaser(delta: float) -> void:
	var direction := player.global_position - global_position
	direction.y = 0.0

	if direction.length_squared() > 0.01:
		direction = direction.normalized()

		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	velocity.y = 0.0

	_horde_move(delta)

	contact_damage_timer = maxf(0.0, contact_damage_timer - delta)

	# Ordinary contact damage only when the physical contact area overlaps.
	if contact_damage_timer <= 0.0 and _player_is_in_contact():
		player.take_damage(_apply_elite_contact_damage(contact_damage))
		contact_damage_timer = contact_damage_cooldown

	update_sprite_facing()

	if Vector2(velocity.x, velocity.z).length() > 0.1:
		play_sprite_animation(&"Walk")
	else:
		play_sprite_animation(&"Idle")





func _process_charger(delta: float) -> void:
	var to_player := player.global_position - global_position
	to_player.y = 0.0

	var distance_to_player := to_player.length()
	var direction := Vector3.ZERO

	if distance_to_player > 0.01:
		direction = to_player.normalized()

	match charger_state:
		&"approach":
			charger_cooldown_timer -= delta

			if _player_is_in_contact():
				_charger_begin_punch()

			elif charger_cooldown_timer <= 0.0:
				charger_state = &"windup"
				charger_state_timer = charger_windup
				charger_direction = direction
				CombatVisualManager.warning_line(global_position, charger_direction, charger_rush_speed * charger_rush_duration, 1.0, charger_windup)

				velocity.x = 0.0
				velocity.z = 0.0

				play_sprite_animation(&"Idle")
			else:
				_set_bounded_velocity(direction, move_speed, delta)
				play_sprite_animation(&"Walk")

		&"windup":
			velocity.x = 0.0
			velocity.z = 0.0
			charger_state_timer -= delta
			play_sprite_animation(&"Idle")

			if charger_state_timer <= 0.0:
				charger_state = &"charge"
				charger_state_timer = charger_rush_duration
				play_sprite_animation(&"Walk")

		&"charge":
			charger_state_timer -= delta

			_set_bounded_velocity(
				charger_direction,
				charger_rush_speed,
				delta
			)

			play_sprite_animation(&"Walk")

			if _player_is_in_contact():
				_charger_begin_punch()
			elif charger_state_timer <= 0.0:
				_charger_begin_recovery()

		&"punch":
			velocity.x = 0.0
			velocity.z = 0.0
			charger_state_timer -= delta
			play_sprite_animation(&"Attack01")

			if (
				not charger_punch_damage_applied
				and charger_state_timer <= 0.25
			):
				charger_punch_damage_applied = true

				# Punch damage requires real body contact at the hit frame.
				if _player_is_in_contact():
					player.take_damage(charger_punch_damage)

			if charger_state_timer <= 0.0:
				_charger_begin_recovery()

		&"recover":
			velocity.x = 0.0
			velocity.z = 0.0
			charger_state_timer -= delta
			play_sprite_animation(&"Idle")

			if charger_state_timer <= 0.0:
				charger_state = &"approach"
				charger_cooldown_timer = charger_cooldown

	velocity.y = 0.0

	_horde_move(delta)
	update_sprite_facing()




func _process_stalker(delta: float) -> void:
	var to_player := player.global_position - global_position
	to_player.y = 0.0

	var distance_to_player := to_player.length()
	var toward_player := Vector3.ZERO

	if distance_to_player > 0.01:
		toward_player = to_player / distance_to_player

	stalker_lunge_cooldown_timer -= delta

	match stalker_state:
		&"orbit":
			if distance_to_player > 0.01:
				var tangent := Vector3(
					-toward_player.z * stalker_orbit_direction,
					0.0,
					toward_player.x * stalker_orbit_direction
				)

				var radial_adjustment := 0.0

				if distance_to_player > (
					stalker_orbit_radius
					+ stalker_orbit_radius_tolerance
				):
					radial_adjustment = 0.65
				elif distance_to_player < (
					stalker_orbit_radius
					- stalker_orbit_radius_tolerance
				):
					radial_adjustment = -0.65

				var orbit_vector := (
					tangent + toward_player * radial_adjustment
				)

				if orbit_vector.length_squared() > 0.01:
					orbit_vector = orbit_vector.normalized()

				_set_bounded_velocity(
					orbit_vector,
					stalker_orbit_speed,
					delta
				)
			else:
				velocity.x = 0.0
				velocity.z = 0.0

			play_sprite_animation(&"Walk")

			if (
				stalker_lunge_cooldown_timer <= 0.0
				and distance_to_player > 0.01
			):
				stalker_state = &"windup"
				stalker_state_timer = stalker_lunge_windup
				stalker_lunge_direction = toward_player
				CombatVisualManager.warning_line(global_position, stalker_lunge_direction, stalker_lunge_speed * stalker_lunge_duration, 0.8, stalker_lunge_windup)
				velocity.x = 0.0
				velocity.z = 0.0

				play_sprite_animation(&"Idle")

		&"windup":
			velocity.x = 0.0
			velocity.z = 0.0
			stalker_state_timer -= delta

			if stalker_state_timer <= 0.0:
				stalker_state = &"lunge"
				stalker_state_timer = stalker_lunge_duration
				stalker_attack_damage_applied = false
				play_monster_animation(&"Run")

		&"lunge":
			stalker_state_timer -= delta

			_set_bounded_velocity(
				stalker_lunge_direction,
				stalker_lunge_speed,
				delta
			)

			play_sprite_animation(&"Walk")

			if _player_is_in_contact():
				stalker_state = &"attack"
				stalker_state_timer = 0.4
				CombatVisualManager.warning_circle(global_position, stalker_attack_range + 0.3, 0.2)
				stalker_attack_damage_applied = false
				velocity.x = 0.0
				velocity.z = 0.0
				play_sprite_animation(stalker_next_attack)

				if stalker_next_attack == &"Attack01":
					stalker_next_attack = &"Attack02"
				else:
					stalker_next_attack = &"Attack01"

			elif stalker_state_timer <= 0.0:
				_stalker_begin_retreat()

		&"attack":
			velocity.x = 0.0
			velocity.z = 0.0
			stalker_state_timer -= delta

			if (
				not stalker_attack_damage_applied
				and stalker_state_timer <= 0.2
			):
				stalker_attack_damage_applied = true

				# The lunge/attack still telegraphs and animates as before,
				# but its damage only connects if the bodies are touching.
				if _player_is_in_contact():
					player.take_damage(stalker_attack_damage)

			if stalker_state_timer <= 0.0:
				_stalker_begin_retreat()

		&"retreat":
			stalker_state_timer -= delta

			_set_bounded_velocity(
				stalker_retreat_direction,
				stalker_retreat_speed,
				delta
			)

			play_sprite_animation(&"Walk")

			if stalker_state_timer <= 0.0:
				stalker_state = &"reposition"
				stalker_state_timer = stalker_reposition_duration
				stalker_orbit_direction *= -1.0

		&"reposition":
			velocity.x = 0.0
			velocity.z = 0.0
			stalker_state_timer -= delta
			play_sprite_animation(&"Idle")

			if stalker_state_timer <= 0.0:
				stalker_state = &"orbit"
				stalker_lunge_cooldown_timer = stalker_lunge_interval

	velocity.y = 0.0

	_horde_move(delta)


func _process_brute(delta: float) -> void:
	var to_player := player.global_position - global_position
	to_player.y = 0.0

	var distance_to_player := to_player.length()
	var direction := Vector3.ZERO

	if distance_to_player > 0.01:
		direction = to_player.normalized()

	brute_attack_cooldown_timer -= delta

	match brute_state:
		&"approach":
			if _player_is_in_contact():
				if brute_attack_cooldown_timer <= 0.0:
					brute_state = &"windup"
					brute_state_timer = brute_windup_duration
					CombatVisualManager.warning_circle(global_position, brute_attack_range, brute_windup_duration + brute_attack_animation_duration * 0.5)
					brute_attack_damage_applied = false

					velocity.x = 0.0
					velocity.z = 0.0

					play_sprite_animation(&"Idle")
			else:
				_set_bounded_velocity(
					direction,
					brute_move_speed,
					delta
				)
				play_sprite_animation(&"Walk")
				update_sprite_facing()

		&"windup":
			velocity.x = 0.0
			velocity.z = 0.0
			brute_state_timer -= delta

			if brute_state_timer <= 0.0:
				brute_state = &"attack"
				brute_state_timer = brute_attack_animation_duration
				play_sprite_animation(&"Attack01")

		&"attack":
			velocity.x = 0.0
			velocity.z = 0.0
			brute_state_timer -= delta

			if (
				not brute_attack_damage_applied
				and brute_state_timer
					<= brute_attack_animation_duration * 0.5
			):
				brute_attack_damage_applied = true

				# The warning circle is unchanged; actual impact needs contact.
				if _player_is_in_contact():
					player.take_damage(brute_attack_damage)

			if brute_state_timer <= 0.0:
				brute_state = &"recover"
				brute_state_timer = brute_recovery_duration
				brute_attack_cooldown_timer = brute_attack_cooldown
				play_sprite_animation(&"Idle")

		&"recover":
			velocity.x = 0.0
			velocity.z = 0.0
			brute_state_timer -= delta
			play_monster_animation(&"Idle")

			if brute_state_timer <= 0.0:
				brute_state = &"approach"

	velocity.y = 0.0

	_horde_move(delta)

func _stalker_begin_retreat() -> void:
	stalker_state = &"retreat"
	stalker_state_timer = stalker_retreat_duration

	stalker_retreat_direction = global_position - player.global_position
	stalker_retreat_direction.y = 0.0

	if stalker_retreat_direction.length_squared() > 0.01:
		stalker_retreat_direction = stalker_retreat_direction.normalized()
	else:
		stalker_retreat_direction = Vector3.BACK

	velocity.x = 0.0
	velocity.z = 0.0


func _set_bounded_velocity(
	direction: Vector3,
	speed: float,
	_delta: float
) -> void:
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed


func _charger_begin_punch() -> void:
	charger_state = &"punch"
	charger_state_timer = 0.45
	CombatVisualManager.warning_circle(global_position, charger_punch_range + 0.25, 0.20)
	charger_punch_damage_applied = false

	velocity.x = 0.0
	velocity.z = 0.0

	play_sprite_animation(&"Attack01")


func _charger_begin_recovery() -> void:
	charger_state = &"recover"
	charger_state_timer = charger_recovery
	charger_cooldown_timer = charger_cooldown

	velocity.x = 0.0
	velocity.z = 0.0

	play_sprite_animation(&"Idle")


func has_monster_animation(animation_name: StringName) -> bool:
	return (
		monster_animation != null
		and monster_animation.has_animation(animation_name)
	)



func update_monster_animation() -> void:
	if monster_animation == null:
		return

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()

	if horizontal_speed > 0.1:
		play_monster_animation(&"Walk")
	else:
		play_monster_animation(&"Idle")





func take_damage(amount: int) -> void:
	_apply_damage(amount, false)


func take_projectile_hit(amount: int, critical: bool) -> void:
	_apply_damage(amount, critical)


func _apply_damage(amount: int, critical: bool) -> void:
	if health <= 0 or is_dying:
		return

	var adjusted_damage: int = maxi(0, _apply_elite_damage_modifier(amount))

# Full damage dealt by the attack, including overkill.
	var displayed_damage: int = adjusted_damage

# Damage actually removed from the enemy's remaining health.
	var actual_damage: int = mini(adjusted_damage, health)

	health -= actual_damage

# Floating combat text shows the full attack damage.
	show_damage_number(displayed_damage, critical)

	var damage_meter = get_tree().current_scene.get_node_or_null(
		"CanvasLayer/DamageMeter"
	)

	if damage_meter != null:
		damage_meter.record_damage(actual_damage)

	if health <= 0:
		is_dying = true

		_elite_death_effect()
		dungeon_enemy_killed.emit(self)

		if player != null and is_instance_valid(player):
			if player.has_method("register_kill"):
				player.register_kill()

		if randf() < magnet_drop_chance:
			var magnet = MAGNET_SCENE.instantiate()
			get_tree().current_scene.add_child(magnet)
			magnet.global_position = global_position + Vector3(0, 0.5, 0)

		# Spawn a collectible run-currency drop; elites have separate odds/amounts.
		var drop_chance: float = elite_currency_drop_chance if is_elite else currency_drop_chance
		if randf() < clampf(drop_chance, 0.0, 1.0):
			var minimum: int = elite_currency_min_drop if is_elite else currency_min_drop
			var maximum: int = elite_currency_max_drop if is_elite else currency_max_drop
			var currency_pickup = CURRENCY_PICKUP_SCRIPT.new()
			currency_pickup.amount = randi_range(maxi(1, mini(minimum, maximum)), maxi(1, maxi(minimum, maximum)))
			get_tree().current_scene.add_child(currency_pickup)
			currency_pickup.global_position = global_position + Vector3(0.0, 0.45, 0.0)

		var xp_amount: int = 1

		if is_elite and not elite_bonus_xp_awarded:
			xp_amount += elite_bonus_xp
			elite_bonus_xp_awarded = true

		if player != null and is_instance_valid(player):
			if player.has_method("gain_xp"):
				player.gain_xp(xp_amount)

		queue_free()


func show_damage_number(amount: int, critical: bool = false) -> void:
	var damage_number = DAMAGE_NUMBER_SCENE.instantiate()
	get_tree().current_scene.add_child(damage_number)

	var spawn_position: Vector3 = global_position + Vector3(0.0, 1.5, 0.0)
	damage_number.global_position = spawn_position
	damage_number.setup(amount, critical)


func update_healthbar() -> void:
	var bar = get_node_or_null("HealthBar/BarFill")

	if bar == null:
		return

	if max_health <= 0:
		return

	var health_percent: float = clampf(
		float(health) / float(max_health),
		0.0,
		1.0
	)

	var bar_mesh = bar.mesh as BoxMesh

	if bar_mesh == null:
		print("BarFill does not use a BoxMesh")
		return

	bar_mesh.size.x = 0.9 * health_percent
	bar.position.x = -0.45 * (1.0 - health_percent)

func play_sprite_animation(_animation_name: StringName) -> void:
	pass


func play_monster_animation(_animation_name: StringName) -> void:
	pass


func update_sprite_facing() -> void:
	if enemy_sprite == null:
		return

	if player == null or not is_instance_valid(player):
		return

	var movement_x := velocity.x

	if absf(movement_x) < 0.05:
		return

	enemy_sprite.flip_h = movement_x < 0.0


func _make_elite() -> void:
	if is_elite:
		return

	is_elite = true
	elite_base_speed = move_speed
	elite_base_health = max_health

	max_health = maxi(
		1,
		roundi(float(max_health) * elite_health_multiplier)
	)
	health = max_health

	# Pick one modifier for this elite.
	elite_modifier = [
		EliteModifier.SWIFT,
		EliteModifier.ARMORED,
		EliteModifier.VOLATILE,
		EliteModifier.COMMANDER
	].pick_random()

	match elite_modifier:
		EliteModifier.SWIFT:
			move_speed *= 1.35
			charger_rush_speed *= 1.2
			stalker_orbit_speed *= 1.2
			stalker_lunge_speed *= 1.2
		EliteModifier.ARMORED:
			pass
		EliteModifier.VOLATILE:
			pass
		EliteModifier.COMMANDER:
			pass

	# Enlarge the visible model without enlarging the collision body.
	elite_visuals = get_node_or_null("MonsterVisual") as Node3D

	if elite_visuals == null:
		elite_visuals = enemy_sprite

	if elite_visuals != null:
		elite_visual_base_scale = elite_visuals.scale
		elite_visuals.scale = elite_visual_base_scale * elite_scale

	_create_elite_ring()


func _create_elite_ring() -> void:
	elite_ring = MeshInstance3D.new()
	elite_ring.name = "EliteGroundRing"

	var torus := TorusMesh.new()
	torus.inner_radius = elite_ring_radius * 0.78
	torus.outer_radius = elite_ring_radius
	torus.rings = 32
	torus.ring_segments = 12

	elite_ring.mesh = torus

	# A TorusMesh lies flat on the XZ plane by default.
	# Keep it horizontal instead of rotating it vertically.
	elite_ring.rotation = Vector3.ZERO

	# Place it at ground level around the enemy's feet.
	elite_ring.position = Vector3(0.0, 0.03, 0.0)

	elite_ring_material = StandardMaterial3D.new()
	elite_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	elite_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	elite_ring_material.albedo_color = Color(1.0, 0.15, 0.05, 0.9)
	elite_ring_material.emission_enabled = true
	elite_ring_material.emission = Color(1.0, 0.05, 0.01)
	elite_ring_material.emission_energy_multiplier = 2.5

	elite_ring.material_override = elite_ring_material
	add_child(elite_ring)


func _process_elite_visuals(delta: float) -> void:
	if not is_elite or not is_instance_valid(elite_ring):
		return

	elite_animation_time += delta

	var pulse := 1.0 + sin(
		elite_animation_time * elite_pulse_speed
	) * 0.12

	elite_ring.scale = Vector3(pulse, 1.0, pulse)

	if elite_ring_material != null:
		var glow := 1.8 + (sin(
			elite_animation_time * elite_pulse_speed
		) + 1.0) * 0.8

		elite_ring_material.emission_energy_multiplier = glow


func _apply_elite_damage_modifier(amount: int) -> int:
	if not is_elite:
		return amount

	if elite_modifier == EliteModifier.ARMORED:
		return maxi(1, roundi(float(amount) * 0.6))

	return amount


func _apply_elite_contact_damage(amount: int) -> int:
	if is_elite:
		return roundi(float(amount) * elite_damage_multiplier)

	return amount


func _elite_death_effect() -> void:
	if not is_elite:
		return

	if elite_modifier == EliteModifier.VOLATILE:
		if player != null and is_instance_valid(player):
			var distance := global_position.distance_to(
				player.global_position
			)

			if distance <= 3.0 and player.has_method("take_damage"):
				player.take_damage(30)


func _buff_nearby_enemies() -> void:
	if not is_elite or elite_modifier != EliteModifier.COMMANDER:
		return

	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self or not is_instance_valid(node):
			continue

		if not node is CharacterBody3D:
			continue

		var other := node as CharacterBody3D

		if global_position.distance_to(other.global_position) > 6.0:
			continue

		if other.has_meta("commander_buffed"):
			continue

		other.set_meta("commander_buffed", true)

		if "move_speed" in other:
			other.set(
				"move_speed",
				float(other.get("move_speed")) * 1.1
			)
func _update_visual_bounce(delta: float) -> void:
	if visual_root == null or not is_instance_valid(visual_root):
		return

	var moving := Vector2(velocity.x, velocity.z).length_squared() > 0.01
	var attacking := false

	match enemy_behavior:
		EnemyAIBehavior.CHARGER:
			attacking = charger_state == &"punch"
		EnemyAIBehavior.STALKER:
			attacking = (
				stalker_state == &"lunge"
				or stalker_state == &"attack"
			)
		EnemyAIBehavior.BRUTE:
			attacking = (
				brute_state == &"windup"
				or brute_state == &"attack"
			)

	if moving or attacking:
		var height := WALK_BOUNCE_HEIGHT
		var speed := WALK_BOUNCE_SPEED

		if attacking:
			height = ATTACK_BOUNCE_HEIGHT
			speed = ATTACK_BOUNCE_SPEED

		bounce_time += delta * speed
		var offset := absf(sin(bounce_time)) * height
		visual_root.position = visual_base_position + Vector3.UP * offset
	else:
		bounce_time = 0.0
		visual_root.position = visual_base_position

func _update_cached_player_position(delta: float) -> void:
	player_position_refresh_timer -= delta

	if player_position_refresh_timer <= 0.0:
		player_position_refresh_timer = PLAYER_POSITION_REFRESH_INTERVAL

		if player != null and is_instance_valid(player):
			cached_player_position = player.global_position


func _horde_move(delta: float) -> void:
	floor_snap_length = 0.75

	if is_on_floor():
		velocity.y = -0.1
	else:
		velocity.y -= gravity * delta

	move_and_slide()

func _exit_tree() -> void:
	var scene := get_tree().current_scene

	if scene == null:
		return

	var manager := scene.find_child("HordeManager", true, false)

	if manager != null and manager.has_method("unregister_enemy"):
		manager.unregister_enemy(self)
