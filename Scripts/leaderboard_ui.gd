
extends CanvasLayer

@onready var leaderboard_panel: Control = $LeaderboardPanel
@onready var run_rows: VBoxContainer = $LeaderboardPanel/OuterFrame/InnerBackground/ContentMargin/MainVBox/RunRows
@onready var status_label: Label = $LeaderboardPanel/OuterFrame/InnerBackground/ContentMargin/MainVBox/StatusLabel
@onready var close_button: Button = $LeaderboardPanel/OuterFrame/InnerBackground/ContentMargin/MainVBox/CloseButton

var row_scene: PackedScene = preload("res://Scenes/LeaderboardRow.tscn")


func _ready() -> void:
	leaderboard_panel.hide()
	LeaderboardService.top_runs_loaded.connect(_on_top_runs_loaded)
	LeaderboardService.request_failed.connect(_on_request_failed)


func open_leaderboard() -> void:
	leaderboard_panel.show()
	status_label.text = "CONNECTING TO THE LEADERBOARDS..."
	LeaderboardService.fetch_top_runs()


func close_leaderboard() -> void:
	leaderboard_panel.hide()


func _on_top_runs_loaded(runs: Array) -> void:
	for child in run_rows.get_children():
		child.queue_free()

	if runs.is_empty():
		status_label.text = "NO RUNS RECORDED YET"
		return

	status_label.text = "TOP RUNS — LIVE ONLINE RECORDS"

	for i in range(runs.size()):
		var row = row_scene.instantiate()
		run_rows.add_child(row)
		row.set_run_data(runs[i], i + 1)


func _on_request_failed(message: String) -> void:
	status_label.text = message


func _on_close_button_pressed() -> void:
	close_leaderboard()
