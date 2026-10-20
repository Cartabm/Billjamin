
extends Area3D

@onready var roof: Node3D = get_parent().get_node("Roof")

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.name == "Player":
		roof.hide()


func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D and body.name == "Player":
		roof.show()
