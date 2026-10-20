
extends Node

func _ready() -> void:
	LeaderboardService.run_submitted.connect(_on_run_submitted)
	LeaderboardService.request_failed.connect(_on_request_failed)

	print("Submitting test run...")
	LeaderboardService.submit_run(
		"TestPlayer",
		25,    # Kills
		8,     # Level
		185,   # Time alive in seconds
		1250   # Score
	)


func _on_run_submitted() -> void:
	print("SUCCESS: Test run saved!")
	LeaderboardService.fetch_top_runs()


func _on_request_failed(message: String) -> void:
	push_error("Leaderboard test failed: " + message)
