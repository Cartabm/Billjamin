
extends Control

@onready var stats_label: Label = $StatsPanel/MarginContainer/StatsLabel
@onready var pause_menu: Control = self
@onready var options_button: Button = $CenterContainer/CenterVBox/OptionsButton
@onready var resume_button: Button = $CenterContainer/CenterVBox/ResumeButton

var player: CharacterBody3D
var enemy_spawner: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	player = get_tree().current_scene.get_node_or_null("Player")
	enemy_spawner = get_tree().current_scene.get_node_or_null("EnemySpawner")
	
	options_button.pressed.connect(_on_options_pressed)

	hide()
	resume_button.pressed.connect(resume_game)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			if get_tree().paused:
				if visible:
					resume_game()
			else:
				if not _other_menu_is_open():
					open_pause_menu()


func _process(_delta: float) -> void:
	if visible:
		update_stats()


func _other_menu_is_open() -> bool:
	var scene_root = get_tree().current_scene
	var upgrade_menu = scene_root.get_node_or_null("CanvasLayer/UpgradeMenu")
	var game_over_menu = scene_root.get_node_or_null("CanvasLayer/GameOverMenu")

	if upgrade_menu != null and upgrade_menu.visible:
		return true

	if game_over_menu != null and game_over_menu.visible:
		return true

	return false


func open_pause_menu() -> void:
	player = get_tree().current_scene.get_node_or_null("Player")
	enemy_spawner = get_tree().current_scene.get_node_or_null("EnemySpawner")

	if player == null:
		return

	update_stats()
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true


func resume_game() -> void:
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func update_stats() -> void:
	if player == null or not is_instance_valid(player):
		return

	var shots_per_second: float = 0.0
	if player.fire_rate > 0.0:
		shots_per_second = 1.0 / player.fire_rate

	var spawn_rate: float = 0.0
	var spawn_interval: float = 0.0

	if enemy_spawner != null and is_instance_valid(enemy_spawner):
		spawn_interval = enemy_spawner.spawn_interval
		if spawn_interval > 0.0:
			spawn_rate = 60.0 / spawn_interval

	stats_label.text = (
		"PLAYER\n"
		+ "Health: %d / %d\n" % [player.current_health, player.max_health]
		+ "Level: %d\n" % player.player_level
		+ "XP: %d / %d\n" % [player.current_xp, player.xp_to_level]
		+ "XP Bonus: +%d%%\n" % [roundi((player.xp_multiplier - 1.0) * 100.0)]
		+ "Movement Speed: %.2f\n\n" % player.move_speed
		+ "COMBAT\n"
		+ "Projectile Damage: %d\n" % player.projectile_damage
		+ "Fire Rate: %.2f shots/sec\n" % shots_per_second
		+ "Projectiles per Shot: %d\n\n" % player.multishot_count
		+ "ENEMIES\n"
		+ "Spawn Interval: %.2f seconds\n" % spawn_interval
		+ "Spawn Rate: %.1f enemies/minute" % spawn_rate
	)
func _on_options_pressed() -> void:
	pause_menu.hide()

	var options_scene = load("res://OptionsMenu.tscn").instantiate()
	options_scene.opened_from_pause_menu = true
	options_scene.process_mode = Node.PROCESS_MODE_ALWAYS
	options_scene.tree_exiting.connect(_on_options_closed)

	get_tree().root.add_child(options_scene)


func _on_options_closed() -> void:
	if is_instance_valid(pause_menu):
		pause_menu.show()
