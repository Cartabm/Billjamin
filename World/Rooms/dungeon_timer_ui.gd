
extends TextureRect

@onready var timer_label: Label = $DungeonTimerLabel

var elapsed_time: float = 0.0
var timer_running: bool = false
var timer_finished: bool = false


func _ready() -> void:
	# Timer stops processing when the game is paused.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	reset_timer()


func _process(delta: float) -> void:
	if not timer_running or timer_finished:
		return

	elapsed_time += delta
	update_timer_display()


func start_timer() -> void:
	if timer_running or timer_finished:
		return

	timer_running = true
	update_timer_display()


func stop_timer() -> void:
	if timer_finished:
		return

	timer_running = false
	timer_finished = true
	update_timer_display()


func reset_timer() -> void:
	elapsed_time = 0.0
	timer_running = false
	timer_finished = false
	update_timer_display()


func update_timer_display() -> void:
	if not is_instance_valid(timer_label):
		return

	var total_seconds: int = int(elapsed_time)
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60

	timer_label.text = "%02d:%02d" % [minutes, seconds]
