extends Node
## Register as an Autoload named RunUpgradeState.
signal state_changed

@export var max_bans: int = 2
@export var reroll_base_cost: int = 25
@export var reroll_cost_step: int = 15

var currency: int = 0
var bans_used: int = 0
var rerolls_used: int = 0
var banned_upgrades: Dictionary = {}

func reroll_cost() -> int:
	return reroll_base_cost + rerolls_used * reroll_cost_step

func bans_remaining() -> int:
	return maxi(0, max_bans - bans_used)

func add_currency(amount: int) -> void:
	currency += maxi(0, amount)
	state_changed.emit()

func buy_reroll() -> bool:
	var price := reroll_cost()
	if currency < price:
		return false
	currency -= price
	rerolls_used += 1
	state_changed.emit()
	return true

func ban_upgrade(upgrade_id: String) -> bool:
	if bans_remaining() <= 0 or banned_upgrades.has(upgrade_id):
		return false
	banned_upgrades[upgrade_id] = true
	bans_used += 1
	state_changed.emit()
	return true

func reset_run() -> void:
	currency = 0
	bans_used = 0
	rerolls_used = 0
	banned_upgrades.clear()
	state_changed.emit()
