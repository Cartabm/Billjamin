
extends Control

@onready var total_damage_label: Label = find_child("TotalDamageLabel", true, false) as Label
@onready var dps_label: Label = find_child("DPSLabel", true, false) as Label

var total_damage: float = 0.0
var recent_damage: Array[Dictionary] = []
var display_window: float = 5.0


func _ready() -> void:
	update_display()


func record_damage(amount: int) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0

	total_damage += amount

	recent_damage.append({
		"time": now,
		"amount": amount
	})

	update_display()


func _process(_delta: float) -> void:
	update_display()


func update_display() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0

	# Remove damage entries older than the display window.
	while not recent_damage.is_empty() and now - float(recent_damage[0]["time"]) > display_window:
		recent_damage.pop_front()

	# Calculate damage dealt during the display window.
	var recent_total: float = 0.0

	for entry in recent_damage:
		recent_total += float(entry["amount"])

	# Calculate rolling DPS.
	var dps: float = recent_total / display_window

	# Update total damage label.
	if is_instance_valid(total_damage_label):
		total_damage_label.text = "%d" % int(total_damage)

	# Update DPS label.
	if is_instance_valid(dps_label):
		dps_label.text = "%d" % int(dps)
