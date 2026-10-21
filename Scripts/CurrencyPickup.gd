extends Node3D
## Lightweight run-currency pickup. No .tscn or imported artwork required.

@export var pickup_radius: float = 1.5
@export var amount: int = 5

var visual: MeshInstance3D
var elapsed: float = 0.0

func _ready() -> void:
	visual = MeshInstance3D.new()
	visual.name = "CoinVisual"
	var mesh := SphereMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.44
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.73, 0.12)
	material.metallic = 0.65
	material.roughness = 0.22
	material.emission_enabled = true
	material.emission = Color(0.8, 0.4, 0.03)
	material.emission_energy_multiplier = 0.7
	visual.material_override = material
	add_child(visual)

func _process(delta: float) -> void:
	elapsed += delta
	if visual != null:
		visual.position.y = sin(elapsed * 3.0) * 0.12
		visual.rotation.y += delta * 2.0

	var scene := get_tree().current_scene
	if scene == null:
		return
	var target := scene.get_node_or_null("Player") as Node3D
	if target == null:
		target = scene.get_node_or_null("TestPlayer") as Node3D
	if target == null:
		for candidate in get_tree().get_nodes_in_group("player"):
			if candidate is Node3D and scene.is_ancestor_of(candidate):
				target = candidate
				break
	if target == null:
		return
	var difference := target.global_position - global_position
	if Vector2(difference.x, difference.z).length_squared() <= pickup_radius * pickup_radius and absf(difference.y) <= 2.0:
		RunUpgradeState.add_currency(amount)
		queue_free()
