extends Control

const INVENTORY_COLUMNS: int = 10
const INVENTORY_ROWS: int = 4
const CELL_SIZE: Vector2 = Vector2(48, 48)
const CELL_SPACING: float = 2.0
const CELL_STEP: float = 50.0

const IRON_CHESTPLATE: ItemDefinition = preload(
	"res://Systems/Inventory/ItemDefinitions/iron_chestplate.tres"
)

@onready var inventory_grid: GridContainer = $InventoryPanel/InventoryGrid
@onready var item_layer: Control = $ItemLayer

var occupied_cells: Dictionary = {}

var dragged_item: Control = null
var drag_start_position: Vector2 = Vector2.ZERO
var drag_mouse_offset: Vector2 = Vector2.ZERO

var pending_item_id: String = ""
var pending_old_position: Vector2 = Vector2.ZERO
var pending_old_grid: Vector2i = Vector2i.ZERO
var pending_new_grid: Vector2i = Vector2i.ZERO
var pending_operation: String = ""


func _ready() -> void:
	create_inventory_grid()
	call_deferred("_align_item_layer")

	InventoryManager.item_move_completed.connect(
		_on_item_move_completed
	)

	InventoryManager.item_drop_completed.connect(
		_on_item_drop_completed
	)

	InventoryManager.item_pickup_completed.connect(
		_on_item_pickup_completed
	)

	InventoryManager.inventory_loaded.connect(
		_on_inventory_reloaded
	)

	if InventoryManager.loading:
		await InventoryManager.inventory_loaded

	print(
		"CHARACTER INVENTORY: ",
		InventoryManager.items.size(),
		" items loaded"
	)

	display_saved_inventory()
	hide()


func _align_item_layer() -> void:
	item_layer.global_position = inventory_grid.global_position
	item_layer.size = inventory_grid.size


func create_inventory_grid() -> void:
	for child in inventory_grid.get_children():
		child.queue_free()

	for y in range(INVENTORY_ROWS):
		for x in range(INVENTORY_COLUMNS):
			var cell := Panel.new()

			cell.custom_minimum_size = CELL_SIZE
			cell.name = "Cell_%d_%d" % [x, y]

			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.12, 0.12, 0.14, 1.0)
			style.border_color = Color(0.35, 0.35, 0.40, 1.0)
			style.set_border_width_all(1)

			cell.add_theme_stylebox_override("panel", style)
			inventory_grid.add_child(cell)


func can_place_item(
	grid_x: int,
	grid_y: int,
	item_width: int,
	item_height: int
) -> bool:
	if item_width <= 0 or item_height <= 0:
		return false

	if grid_x < 0 or grid_y < 0:
		return false

	if grid_x + item_width > INVENTORY_COLUMNS:
		return false

	if grid_y + item_height > INVENTORY_ROWS:
		return false

	for y in range(grid_y, grid_y + item_height):
		for x in range(grid_x, grid_x + item_width):
			if occupied_cells.has(Vector2i(x, y)):
				return false

	return true


func update_item_occupied_cells(
	item_id: String,
	grid_x: int,
	grid_y: int,
	item_width: int,
	item_height: int
) -> bool:
	if item_width <= 0 or item_height <= 0:
		return false

	if grid_x < 0 or grid_y < 0:
		return false

	if grid_x + item_width > INVENTORY_COLUMNS:
		return false

	if grid_y + item_height > INVENTORY_ROWS:
		return false

	for y in range(grid_y, grid_y + item_height):
		for x in range(grid_x, grid_x + item_width):
			var cell := Vector2i(x, y)

			if occupied_cells.has(cell):
				if occupied_cells[cell] != item_id:
					return false

	for cell in occupied_cells.keys():
		if occupied_cells[cell] == item_id:
			occupied_cells.erase(cell)

	for y in range(grid_y, grid_y + item_height):
		for x in range(grid_x, grid_x + item_width):
			occupied_cells[Vector2i(x, y)] = item_id

	return true


func clear_item_occupied_cells(item_id: String) -> void:
	for cell in occupied_cells.keys():
		if occupied_cells[cell] == item_id:
			occupied_cells.erase(cell)


func place_item(
	item_id: String,
	grid_x: int,
	grid_y: int,
	item_width: int,
	item_height: int,
	item_icon: Texture2D = null
) -> bool:
	if not can_place_item(
		grid_x,
		grid_y,
		item_width,
		item_height
	):
		return false

	for y in range(grid_y, grid_y + item_height):
		for x in range(grid_x, grid_x + item_width):
			occupied_cells[Vector2i(x, y)] = item_id

	display_item(
		item_id,
		grid_x,
		grid_y,
		item_width,
		item_height,
		item_icon
	)

	return true


func display_item(
	item_id: String,
	grid_x: int,
	grid_y: int,
	item_width: int,
	item_height: int,
	item_icon: Texture2D = null
) -> void:
	var item := Panel.new()
	item.name = "Item_" + item_id
	item.mouse_filter = Control.MOUSE_FILTER_STOP

	item.gui_input.connect(
		_on_inventory_item_input.bind(item_id)
	)

	item.position = Vector2(
		grid_x * CELL_STEP,
		grid_y * CELL_STEP
	)

	item.size = Vector2(
		item_width * CELL_SIZE.x + (item_width - 1) * CELL_SPACING,
		item_height * CELL_SIZE.y + (item_height - 1) * CELL_SPACING
	)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.28, 0.42, 0.58)
	style.border_color = Color(0.65, 0.80, 0.95)
	style.set_border_width_all(2)

	item.add_theme_stylebox_override("panel", style)
	item_layer.add_child(item)

	if item_icon != null:
		var icon := TextureRect.new()
		icon.name = "ItemIcon"
		icon.texture = item_icon

		icon.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)

		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

		item.add_child(icon)


func get_item_definition(item_id: String) -> ItemDefinition:
	match item_id:
		"iron_chestplate":
			return IRON_CHESTPLATE

		_:
			push_warning("Unknown item definition: " + item_id)
			return null


func place_item_definition(
	item_definition: ItemDefinition,
	grid_x: int,
	grid_y: int
) -> bool:
	if item_definition == null:
		return false

	return place_item(
		item_definition.item_id,
		grid_x,
		grid_y,
		item_definition.grid_width,
		item_definition.grid_height,
		item_definition.item_icon
	)


func get_saved_item_data(item_id: String) -> Dictionary:
	for entry in InventoryManager.items:
		if str(entry.get("id", "")) == item_id:
			return entry

	return {}


func display_saved_inventory() -> void:
	occupied_cells.clear()

	for child in item_layer.get_children():
		child.queue_free()

	for item_data in InventoryManager.items:
		if str(item_data.get("location", "")) != "inventory":
			continue

		var definition_id := str(
			item_data.get("item_definition_id", "")
		)

		var definition := get_item_definition(definition_id)

		if definition == null:
			continue

		if item_data.get("grid_x") == null \
		or item_data.get("grid_y") == null:
			push_warning(
				"Missing inventory position for: " + definition_id
			)
			continue

		var grid_x := int(item_data["grid_x"])
		var grid_y := int(item_data["grid_y"])
		var instance_id := str(item_data.get("id", ""))

		if instance_id.is_empty():
			push_warning(
				"Saved item has no instance ID: " + definition_id
			)
			continue

		var placed := place_item(
			instance_id,
			grid_x,
			grid_y,
			definition.grid_width,
			definition.grid_height,
			definition.item_icon
		)

		if not placed:
			push_warning(
				"Inventory item overlaps another item or is outside the grid: "
				+ definition_id
			)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo \
		and event.keycode == KEY_B:
			visible = not visible
			get_viewport().set_input_as_handled()


func _on_inventory_item_input(
	event: InputEvent,
	item_id: String
) -> void:
	if not event is InputEventMouseButton:
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if not event.pressed:
		return

	if InventoryManager.moving_item or InventoryManager.dropping_item:
		return

	if not pending_item_id.is_empty():
		return

	if dragged_item != null:
		return

	var item_node := item_layer.get_node_or_null(
		"Item_" + item_id
	) as Control

	if item_node == null:
		return

	dragged_item = item_node
	drag_start_position = item_node.position
	drag_mouse_offset = item_node.get_local_mouse_position()

	print("STARTED DRAGGING: ", item_id)


func _process(_delta: float) -> void:
	if dragged_item == null:
		return

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var mouse_position := item_layer.get_local_mouse_position()

		dragged_item.position = (
			mouse_position - drag_mouse_offset
		)
		return

	var mouse_position := item_layer.get_local_mouse_position()
	var drop_position := mouse_position - drag_mouse_offset

	var grid_x := roundi(drop_position.x / CELL_STEP)
	var grid_y := roundi(drop_position.y / CELL_STEP)

	var item_id := dragged_item.name.trim_prefix("Item_")
	var item_data := get_saved_item_data(item_id)

	if item_data.is_empty():
		_cancel_drag()
		return

	var definition := get_item_definition(
		str(item_data.get("item_definition_id", ""))
	)

	if definition == null:
		_cancel_drag()
		return

	var old_grid := Vector2i(
		int(item_data.get("grid_x", 0)),
		int(item_data.get("grid_y", 0))
	)

	# Only treat a release outside the entire inventory panel
	# as a world-drop request.
	var mouse_global := get_global_mouse_position()
	var panel_rect: Rect2 = $InventoryPanel.get_global_rect()

	if not panel_rect.has_point(mouse_global):
		dragged_item.position = drag_start_position
		dragged_item = null

		_request_world_drop(item_id, old_grid)
		return

	var new_grid := Vector2i(grid_x, grid_y)

	var valid := update_item_occupied_cells(
		item_id,
		grid_x,
		grid_y,
		definition.grid_width,
		definition.grid_height
	)

	if not valid:
		_cancel_drag()
		print("INVALID DROP POSITION")
		return

	dragged_item.position = Vector2(
		grid_x * CELL_STEP,
		grid_y * CELL_STEP
	)

	dragged_item = null

	if new_grid == old_grid:
		return

	pending_item_id = item_id
	pending_operation = "move"
	pending_old_position = drag_start_position
	pending_old_grid = old_grid
	pending_new_grid = new_grid

	print("SAVING ITEM POSITION: ", grid_x, ", ", grid_y)

	InventoryManager.move_item(
		item_id,
		grid_x,
		grid_y
	)


func _cancel_drag() -> void:
	if dragged_item != null:
		dragged_item.position = drag_start_position
		dragged_item = null


func _request_world_drop(
	item_id: String,
	old_grid: Vector2i
) -> void:
	# Only Town drops are currently supported.
	var town := get_tree().current_scene

	if town == null or town.name != "Town":
		print("DROP CANCELLED: Not in Town")
		return

	# Use the actual Player node, not the mouse cursor's
	# world position. The item will appear near the player.
	var player := town.get_node_or_null("Player") as Node3D

	if player == null:
		print("DROP CANCELLED: Player node not found")
		return

	var forward := -player.global_transform.basis.z.normalized()
	forward.y = 0.0

	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD

	var world_position := player.global_position + forward.normalized() * 1.5

	pending_item_id = item_id
	pending_operation = "drop"
	pending_old_grid = old_grid
	pending_old_position = drag_start_position

	print("REQUESTING WORLD DROP: ", item_id)

	InventoryManager.drop_item(
		item_id,
		world_position,
		"Town"
	)


func _on_item_move_completed(
	success: bool,
	message: String
) -> void:
	print("INVENTORY SAVE: ", success, " - ", message)

	if pending_operation != "move":
		return

	var item_id := pending_item_id
	var item_data := get_saved_item_data(item_id)

	var item_node := item_layer.get_node_or_null(
		"Item_" + item_id
	) as Control

	var definition: ItemDefinition = null

	if not item_data.is_empty():
		definition = get_item_definition(
			str(item_data.get("item_definition_id", ""))
		)

	if success:
		for index in range(InventoryManager.items.size()):
			if str(InventoryManager.items[index].get("id", "")) == item_id:
				InventoryManager.items[index]["grid_x"] = pending_new_grid.x
				InventoryManager.items[index]["grid_y"] = pending_new_grid.y
				break

		print("ITEM POSITION SAVED SUCCESSFULLY")
	else:
		if item_node != null:
			item_node.position = pending_old_position

		if definition != null:
			update_item_occupied_cells(
				item_id,
				pending_old_grid.x,
				pending_old_grid.y,
				definition.grid_width,
				definition.grid_height
			)

		print("ITEM POSITION RESTORED")

	_clear_pending_operation()


func _on_item_drop_completed(
	success: bool,
	message: String
) -> void:
	print("WORLD DROP: ", success, " - ", message)

	if pending_operation != "drop":
		return

	if success:
		var item_id := pending_item_id

		clear_item_occupied_cells(item_id)

		var item_node := item_layer.get_node_or_null(
			"Item_" + item_id
		)

		if item_node != null:
			item_node.queue_free()

		for index in range(InventoryManager.items.size()):
			if str(InventoryManager.items[index].get("id", "")) == item_id:
				InventoryManager.items[index]["location"] = "ground"
				InventoryManager.items[index]["grid_x"] = null
				InventoryManager.items[index]["grid_y"] = null
				break

		print("ITEM REMOVED FROM INVENTORY AFTER CONFIRMED DROP")
	else:
		print("DROP FAILED: Item remains in inventory")

	_clear_pending_operation()


func _clear_pending_operation() -> void:
	pending_item_id = ""
	pending_operation = ""


func _on_item_pickup_completed(
	success: bool,
	message: String
) -> void:
	print("ITEM PICKUP: ", success, " - ", message)

	if success:
		InventoryManager.load_inventory()


func _on_inventory_reloaded(
	success: bool,
	message: String
) -> void:
	if not success:
		push_warning("INVENTORY RELOAD: " + message)
		return

	if not pending_item_id.is_empty() or dragged_item != null:
		return

	display_saved_inventory()
	print("INVENTORY UI REFRESHED")

var dragging_inventory_window: bool = false


func _on_drag_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging_inventory_window = event.pressed

	elif event is InputEventMouseMotion and dragging_inventory_window:
		var panel: Control = $InventoryPanel
		var item_layer: Control = $ItemLayer
		var header: Control = $DragHeader

		var viewport_size: Vector2 = get_viewport_rect().size

		# Calculate the combined boundaries of the panel and header.
		var combined_rect: Rect2 = panel.get_global_rect().merge(
			header.get_global_rect()
		)

		# Calculate how far the window can move.
		var movement: Vector2 = event.relative

		movement.x = clampf(
			movement.x,
			-combined_rect.position.x,
			viewport_size.x - combined_rect.end.x
		)

		movement.y = clampf(
			movement.y,
			-combined_rect.position.y,
			viewport_size.y - combined_rect.end.y
		)

		# Move all three elements together.
		panel.position += movement
		item_layer.position += movement
		header.position += movement
