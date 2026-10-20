
extends RefCounted
class_name PlayerSave

const CURRENT_SAVE_VERSION: int = 1

var player_id: String = ""
var display_name: String = ""

var total_runs: int = 0
var total_wins: int = 0
var currency: int = 0

var unlocked_items: Array[String] = []
var inventory: Array[Dictionary] = []
var equipped_items: Dictionary = {}
var unlocked_upgrades: Array[String] = []


func to_dictionary() -> Dictionary:
	return {
		"save_version": CURRENT_SAVE_VERSION,
		"player_id": player_id,
		"display_name": display_name,
		"total_runs": total_runs,
		"total_wins": total_wins,
		"currency": currency,
		"unlocked_items": unlocked_items,
		"inventory": inventory,
		"equipped_items": equipped_items,
		"unlocked_upgrades": unlocked_upgrades
	}


func load_from_dictionary(data: Dictionary) -> void:
	player_id = str(data.get("player_id", ""))
	display_name = str(data.get("display_name", ""))

	total_runs = maxi(0, int(data.get("total_runs", 0)))
	total_wins = maxi(0, int(data.get("total_wins", 0)))
	currency = maxi(0, int(data.get("currency", 0)))

	unlocked_items.clear()
	for item in data.get("unlocked_items", []):
		unlocked_items.append(str(item))

	inventory.clear()
	for item in data.get("inventory", []):
		if item is Dictionary:
			inventory.append(item.duplicate(true))

	equipped_items = data.get("equipped_items", {}).duplicate(true)
	unlocked_upgrades.clear()
	for upgrade in data.get("unlocked_upgrades", []):
		unlocked_upgrades.append(str(upgrade))
