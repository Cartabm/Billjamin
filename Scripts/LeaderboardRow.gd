
extends PanelContainer

@onready var rank_label: Label = $RowMargin/Columns/RankLabel
@onready var player_label: Label = $RowMargin/Columns/PlayerLabel
@onready var kills_label: Label = $RowMargin/Columns/KillsLabel
@onready var level_label: Label = $RowMargin/Columns/LevelLabel
@onready var time_label: Label = $RowMargin/Columns/TimeLabel
@onready var score_label: Label = $RowMargin/Columns/ScoreLabel


func set_run_data(run: Dictionary, rank: int) -> void:
	print("ACTUAL ROW TREE:")
	print_tree_pretty()
	
	rank_label.text = "%02d" % rank
	player_label.text = str(run.get("player_name", "Unknown"))
	kills_label.text = str(run.get("kills", 0))
	level_label.text = str(run.get("player_level", 1))
	time_label.text = format_time(int(run.get("time_alive_seconds", 0)))
	score_label.text = str(run.get("score", 0))



func format_time(total_seconds: int) -> String:
	var minutes: int = floori(float(total_seconds) / 60.0)
	var seconds: int = total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]
