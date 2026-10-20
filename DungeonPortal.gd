extends Node3D

signal portal_entered

@export var activation_distance: float = 3.0
var player: Node3D
var ring: MeshInstance3D
var inner: MeshInstance3D
var prompt: Label3D
var elapsed: float = 0.0
var was_pressed: bool = false
var used: bool = false

func _ready() -> void:
	player = get_tree().current_scene.get_node_or_null("Player") as Node3D
	_build_visuals()

func _build_visuals() -> void:
	ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.15
	torus.outer_radius = 1.48
	torus.rings = 48
	torus.ring_segments = 24
	ring.mesh = torus
	ring.rotation.x = PI * 0.5
	ring.position.y = 1.75
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.38, 0.12, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.15, 1.0)
	mat.emission_energy_multiplier = 4.0
	ring.material_override = mat
	add_child(ring)

	inner = MeshInstance3D.new()
	var disk := SphereMesh.new()
	disk.radius = 1.16
	disk.height = 2.32
	inner.mesh = disk
	inner.position.y = 1.75
	inner.scale = Vector3(1.0, 1.0, 0.12)
	var core := StandardMaterial3D.new()
	core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core.albedo_color = Color(0.18, 0.55, 1.0, 0.65)
	core.emission_enabled = true
	core.emission = Color(0.2, 0.45, 1.0)
	core.emission_energy_multiplier = 2.5
	core.cull_mode = BaseMaterial3D.CULL_DISABLED
	inner.material_override = core
	add_child(inner)

	prompt = Label3D.new()
	prompt.text = "NEXT FLOOR\nPress E to Enter"
	prompt.font_size = 40
	prompt.pixel_size = 0.006
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.no_depth_test = true
	prompt.outline_size = 8
	prompt.modulate = Color(0.8, 0.85, 1.0)
	prompt.position.y = 3.5
	prompt.visible = false
	add_child(prompt)

func _process(delta: float) -> void:
	elapsed += delta
	ring.rotation.z += delta * 0.65
	inner.scale = Vector3(1.0 + sin(elapsed * 3.0) * 0.04, 1.0, 0.12)
	if player == null or not is_instance_valid(player):
		player = get_tree().current_scene.get_node_or_null("Player") as Node3D
		return
	var distance := Vector2(global_position.x - player.global_position.x, global_position.z - player.global_position.z).length()
	var nearby := distance <= activation_distance
	prompt.visible = nearby
	var pressed := Input.is_key_pressed(KEY_E)
	if nearby and pressed and not was_pressed and not used:
		used = true
		portal_entered.emit()
	was_pressed = pressed
