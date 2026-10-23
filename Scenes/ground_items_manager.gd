
extends Node3D

const GROUND_ITEM_SCENE: PackedScene = preload(
	"res://Systems/Inventory/ground_item.tscn"
)


func _ready() -> void:
	InventoryManager.ground_items_loaded.connect(
		_on_ground_items_loaded
	)

	InventoryManager.item_drop_completed.connect(
		_on_item_drop_completed
	)

	InventoryManager.item_pickup_completed.connect(
		_on_item_pickup_completed
	)

	_start_ground_item_loading()


func _start_ground_item_loading() -> void:
	# Wait until the inventory finishes loading.
	if InventoryManager.loading:
		await InventoryManager.inventory_loaded

	# If no inventory data is available, load it first.
	if InventoryManager.items.is_empty():
		InventoryManager.load_inventory()

		if InventoryManager.loading:
			var result: Array = await InventoryManager.inventory_loaded

			if not result[0]:
				push_warning(
					"Cannot display ground items: inventory failed to load."
				)
				return

	# Ground items need inventory data to identify their icons.
	InventoryManager.load_ground_items()


func _on_ground_items_loaded(
	success: bool,
	message: String
) -> void:
	if not success:
		push_warning("GROUND ITEMS: " + message)
		return

	_display_ground_items()


func _display_ground_items() -> void:
	# Remove previously displayed items.
	for child in get_children():
		child.queue_free()

	for ground_data in InventoryManager.ground_items:
		var item_id := str(ground_data.get("item_id", ""))
		var character_id := str(
			ground_data.get("character_id", "")
		)

		var definition_id := _find_item_definition(item_id)

		if definition_id.is_empty():
			push_warning(
				"Could not find definition for ground item: "
				+ item_id
			)
			continue

		var ground_item := GROUND_ITEM_SCENE.instantiate() as Node3D

		add_child(ground_item)

		ground_item.name = "GroundItem_" + item_id

		ground_item.global_position = Vector3(
			float(ground_data.get("world_position_x", 0.0)),
			float(ground_data.get("world_position_y", 0.0)),
			float(ground_data.get("world_position_z", 0.0))
		)

		ground_item.setup_item(
			item_id,
			definition_id,
			character_id
		)

	print(
		"GROUND ITEMS DISPLAYED: ",
		get_child_count()
	)


func _find_item_definition(item_id: String) -> String:
	for item_data in InventoryManager.items:
		if str(item_data.get("id", "")) == item_id:
			return str(
				item_data.get("item_definition_id", "")
			)

	return ""


func _on_item_drop_completed(
	success: bool,
	_message: String
) -> void:
	if success:
		InventoryManager.load_ground_items()


func _on_item_pickup_completed(
	success: bool,
	_message: String
) -> void:
	if success:
		InventoryManager.load_ground_items()
