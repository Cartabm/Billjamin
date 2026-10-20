extends Node3D
## Lightweight articulated animation for the existing Crossbow Ranger mesh.
## This is NOT a skeletal rig; it animates separate rigid mesh parts.
## Call set_movement(speed_ratio) from your Player controller (0.0 idle, 1.0 run).
## Call fire() when shooting, reload() when reloading.

@export_range(0.0, 1.0, 0.01) var movement: float = 0.0
@export var animate_automatically: bool = true
@export var walk_cycle_speed: float = 8.0
@export var walk_swing_degrees: float = 22.0

var _time: float = 0.0
var _shot: float = 0.0
var _reload: float = 0.0
var _parts: Dictionary = {}
var _rest: Dictionary = {}
@export var crossbow_offset: Vector3 = Vector3(0.48, 0.18, -0.28)

const GROUPS := {
    "left_leg": ["left_boot", "left_greave", "left_knee", "leg_strap_-1"],
    "right_leg": ["right_boot", "right_greave", "right_knee", "leg_strap_1"],
    "left_arm": ["left_pauldron", "left_upper_arm", "left_bracer", "left_glove"],
    "right_arm": ["right_pauldron", "right_upper_arm", "right_bracer", "right_glove"],
    "crossbow": ["crossbow_stock", "crossbow_grip", "crossbow_trigger", "crossbow_metal_track", "crossbow_left_limb", "crossbow_right_limb", "crossbow_left_metal_tip", "crossbow_right_metal_tip", "crossbow_string_left", "crossbow_string_right", "loaded_bolt", "bolt_tip", "bolt_fletch_-1", "bolt_fletch_1"],
    "cloak": ["tattered_cloak"]
}
const PIVOTS := {
    "left_leg": Vector3(-0.22, 1.04, 0.0),
    "right_leg": Vector3(0.22, 1.04, 0.0),
    "left_arm": Vector3(-0.55, 2.03, 0.0),
    "right_arm": Vector3(0.55, 2.03, 0.0),
    "crossbow": Vector3(0.0, 1.48, -0.46),
    "cloak": Vector3(0.0, 2.02, 0.35)
}

func _ready() -> void:
    # The GLB contains individual mesh nodes, so we can articulate them without modifying the original asset.
    var model := get_node_or_null("Billjamin_Crossbow_Ranger") as Node3D
    if model == null:
        push_warning("Crossbow Ranger model child not found.")
        return
    for group_name in GROUPS.keys():
        var pivot := Node3D.new()
        pivot.name = group_name + "_pivot"
        model.add_child(pivot)
        pivot.position = PIVOTS[group_name]
        for part_name in GROUPS[group_name]:
            var part := model.find_child(part_name, true, false) as Node3D
            if part != null and part != pivot:
                part.reparent(pivot, true)
        _parts[group_name] = pivot
        _rest[group_name] = pivot.transform
    # Move the entire crossbow assembly away from the chest.
    var weapon_pivot: Node3D = _parts.get("crossbow")
    if weapon_pivot != null:
        for child in weapon_pivot.get_children():
            if child is Node3D:
                child.position += crossbow_offset

func set_movement(speed_ratio: float) -> void:
    movement = clampf(speed_ratio, 0.0, 1.0)

func fire() -> void:
    _shot = 1.0

func reload() -> void:
    _reload = 1.0

func _process(delta: float) -> void:
    if _parts.is_empty():
        return
    if animate_automatically:
        var actor := get_parent() as CharacterBody3D
        if actor != null:
            var horizontal_speed := Vector2(actor.velocity.x, actor.velocity.z).length()
            movement = clampf(horizontal_speed / 5.0, 0.0, 1.0)
    _time += delta * walk_cycle_speed
    _shot = maxf(0.0, _shot - delta * 5.0)
    _reload = maxf(0.0, _reload - delta * 1.5)
    var stride := sin(_time) * deg_to_rad(walk_swing_degrees) * movement
    var bob := absf(sin(_time)) * 0.035 * movement
    var idle_breath := sin(_time * 0.22) * 0.012
    var left_leg: Node3D = _parts["left_leg"]
    var right_leg: Node3D = _parts["right_leg"]
    var left_arm: Node3D = _parts["left_arm"]
    var right_arm: Node3D = _parts["right_arm"]
    var weapon: Node3D = _parts["crossbow"]
    var cloak: Node3D = _parts["cloak"]
    left_leg.rotation.x = stride
    right_leg.rotation.x = -stride
    left_arm.rotation.x = -stride * 0.35 - _reload * 0.25
    right_arm.rotation.x = stride * 0.35 - _shot * 0.18
    weapon.rotation.x = -_shot * 0.16 + _reload * 0.13
    weapon.position.y = PIVOTS["crossbow"].y + bob + idle_breath
    cloak.rotation.x = -0.035 + sin(_time * 0.5) * 0.04 + movement * 0.09
