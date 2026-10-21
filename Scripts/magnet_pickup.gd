
extends Area3D

@export var rotation_speed: float = 2.0
@export var bob_height: float = 0.15
@export var bob_speed: float = 3.0

var animation_time: float = 0.0
var starting_height: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	starting_height = position.y


func _process(delta: float) -> void:
	animation_time += delta
	rotation.y += rotation_speed * delta
	position.y = starting_height + sin(animation_time * bob_speed) * bob_height


func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		activate_magnet()
		queue_free()


func activate_magnet() -> void:
	var gems = get_tree().current_scene.find_children("*", "Area3D", true, false)
	var attracted_count: int = 0

	for gem in gems:
		if gem != self and gem.has_method("activate_magnet_attraction"):
			gem.activate_magnet_attraction()
			attracted_count += 1

	print("Magnet activated. XP gems attracted: ", attracted_count)
