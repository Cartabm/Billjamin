
extends Node3D

const PICKUP_DISTANCE: float = 2.5

var item_instance_id: String = ""
var item_definition_id: String = ""
var character_id: String = ""
@onready var loot_label_display: Sprite3D = $LootLabelDisplay

var loot_label_hovered: bool = false

@onready var item_sprite: Sprite3D = $Sprite3D
@onready var loot_label_viewport: SubViewport = $LootLabelViewport


func setup_item(
	instance_id: String,
	definition_id: String,
	owner_character_id: String
) -> void:
	item_instance_id = instance_id
	item_definition_id = definition_id
	var display_name: String = item_definition_id.replace("_", " ").capitalize()

	loot_label_viewport.set_item_name(display_name)
	character_id = owner_character_id

	_update_item_visual()


func _update_item_visual() -> void:
	if not is_node_ready():
		await ready

	if item_sprite == null:
		push_error("GROUND ITEM: Sprite3D node not found.")
		return

	match item_definition_id:
		"iron_chestplate":
			item_sprite.texture = preload(
				"res://Assets/Items/Icons/iron_chestplate.jpg"
			)

		_:
			push_warning(
				"Unknown ground item definition: "
				+ item_definition_id
			)


func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if not event.pressed:
		return

	if not loot_label_hovered:
		return

	if item_instance_id.is_empty():
		return

	if not CharacterManager.has_selected_character():
		return

	if character_id != CharacterManager.selected_character_id:
		return

	var scene := get_tree().current_scene

	if scene == null:
		return

	var player := scene.get_node_or_null("Player") as Node3D

	if player == null:
		return

	if player.global_position.distance_to(global_position) > PICKUP_DISTANCE:
		return

	if InventoryManager.picking_up_item:
		return

	visible = false

	InventoryManager.pickup_item(item_instance_id)
	get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not is_instance_valid(loot_label_display):
		return

	if loot_label_display.texture == null:
		return

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var viewport_size := Vector2(
		loot_label_display.texture.get_width(),
		loot_label_display.texture.get_height()
	)

	var screen_center := camera.unproject_position(
		loot_label_display.global_position
	)

	var screen_height := (
		viewport_size.y
		* loot_label_display.pixel_size
		* camera.get_viewport().get_visible_rect().size.y
		/ 10.0
	)

	var screen_width := (
		screen_height
		* viewport_size.x
		/ maxf(viewport_size.y, 1.0)
	)

	var mouse_position := get_viewport().get_mouse_position()

	var label_rect := Rect2(
		screen_center - Vector2(screen_width, screen_height) / 2.0,
		Vector2(screen_width, screen_height)
	)

	var hovering := label_rect.has_point(mouse_position)

	if hovering != loot_label_hovered:
		loot_label_hovered = hovering
		$LootLabelViewport.set_hovered(hovering)
