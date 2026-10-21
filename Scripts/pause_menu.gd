extends Control

@onready var stats_label: Label = $StatsPanel/MarginContainer/StatsLabel
@onready var pause_menu: Control = self
@onready var options_button: Button = $CenterContainer/CenterVBox/OptionsButton
@onready var resume_button: Button = $CenterContainer/CenterVBox/ResumeButton

var player: CharacterBody3D
var enemy_spawner: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_find_game_nodes()
	options_button.pressed.connect(_on_options_pressed)
	resume_button.pressed.connect(resume_game)
	hide()


func _find_game_nodes() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return

	player = scene_root.find_child("TestPlayer", true, false) as CharacterBody3D
	if player == null:
		player = scene_root.find_child("Player", true, false) as CharacterBody3D

	enemy_spawner = scene_root.find_child("EnemySpawner", true, false)


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
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return false

	var upgrade_menu: Node = scene_root.find_child("UpgradeMenu", true, false)
	var game_over_menu: Node = scene_root.find_child("GameOverMenu", true, false)

	if upgrade_menu is CanvasItem and upgrade_menu.visible:
		return true
	if game_over_menu is CanvasItem and game_over_menu.visible:
		return true
	return false


func open_pause_menu() -> void:
	_find_game_nodes()
	if player == null:
		push_warning("PauseMenu: Neither TestPlayer nor Player was found.")
		return

	update_stats()
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true


func resume_game() -> void:
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _stat(property_name: String, default_value: Variant) -> Variant:
	if player == null or not is_instance_valid(player):
		return default_value
	var value: Variant = player.get(property_name)
	return default_value if value == null else value


func update_stats() -> void:
	if player == null or not is_instance_valid(player):
		return

	var text_value: String = (
		"PLAYER\n"
		+ "Health: %d / %d\n" % [int(_stat("current_health", 0)), int(_stat("max_health", 100))]
		+ "Level: %d\n" % int(_stat("player_level", 1))
		+ "XP: %d / %d\n" % [int(_stat("current_xp", 0)), int(_stat("xp_to_level", 5))]
		+ "XP Bonus: +%d%%\n" % roundi((float(_stat("xp_multiplier", 1.0)) - 1.0) * 100.0)
		+ "Movement Speed: %.2f\n\n" % float(_stat("move_speed", 6.0))
		+ "COMBAT\n"
	)

	var is_rogue: bool = player.name == "TestPlayer" or player.get("melee_damage") != null
	if is_rogue:
		var attack_interval: float = float(_stat("attack_interval", 0.4))
		var attacks_per_second: float = 0.0
		if attack_interval > 0.0:
			attacks_per_second = 1.0 / attack_interval
		text_value += (
			"Melee Damage: %d\n" % int(_stat("melee_damage", 10))
			+ "Attack Rate: %.2f attacks/sec\n" % attacks_per_second
			+ "Auto-Attack Range: %.2f\n\n" % float(_stat("auto_attack_range", 5.0))
		)
	else:
		var fire_rate: float = float(_stat("fire_rate", 0.4))
		var shots_per_second: float = 0.0
		if fire_rate > 0.0:
			shots_per_second = 1.0 / fire_rate
		text_value += (
			"Projectile Damage: %d\n" % int(_stat("projectile_damage", 10))
			+ "Fire Rate: %.2f shots/sec\n" % shots_per_second
			+ "Projectiles per Shot: %d\n\n" % int(_stat("multishot_count", 1))
		)

	if enemy_spawner != null and is_instance_valid(enemy_spawner):
		var interval_value: Variant = enemy_spawner.get("spawn_interval")
		if interval_value != null:
			var spawn_interval: float = float(interval_value)
			var spawn_rate: float = 0.0
			if spawn_interval > 0.0:
				spawn_rate = 60.0 / spawn_interval
			text_value += (
				"ENEMIES\n"
				+ "Spawn Interval: %.2f seconds\n" % spawn_interval
				+ "Spawn Rate: %.1f enemies/minute" % spawn_rate
			)

	stats_label.text = text_value


func _on_options_pressed() -> void:
	pause_menu.hide()
	var options_resource: PackedScene = load("res://Scenes/optionsmenu.tscn") as PackedScene
	if options_resource == null:
		push_error("PauseMenu: Could not load res://OptionsMenu.tscn")
		pause_menu.show()
		return
	var options_scene: Node = options_resource.instantiate()
	options_scene.set("opened_from_pause_menu", true)
	options_scene.process_mode = Node.PROCESS_MODE_ALWAYS
	options_scene.tree_exiting.connect(_on_options_closed)
	get_tree().root.add_child(options_scene)


func _on_options_closed() -> void:
	if is_instance_valid(pause_menu):
		pause_menu.show()


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_return_to_town_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/Town.tscn")
