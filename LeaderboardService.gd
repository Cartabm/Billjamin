
extends Node

signal top_runs_loaded(runs: Array)
signal run_submitted
signal request_failed(message: String)

# Replace these two values with your own Supabase details.
const SUPABASE_URL: String = "https://lpdjolhgqsixljrwngbb.supabase.co"
const SUPABASE_KEY: String = "sb_publishable_eFz2VJumefd_7iRxGcBO4Q_IdshILqM"


func submit_run(
	player_name: String,
	kills: int,
	player_level: int,
	time_alive_seconds: int,
	score: int
) -> void:
	var http := HTTPRequest.new()
	add_child(http)

	http.request_completed.connect(_on_submit_completed.bind(http))

	var url := SUPABASE_URL.trim_suffix("/") + "/rest/v1/run_records"

	var headers := PackedStringArray([
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + SUPABASE_KEY,
		"Content-Type: application/json",
		"Prefer: return=minimal"
	])

	var data := {
		"player_name": player_name,
		"kills": kills,
		"player_level": player_level,
		"time_alive_seconds": time_alive_seconds,
		"score": score
	}

	var error := http.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(data)
	)

	if error != OK:
		request_failed.emit("Could not start score submission. Error: %s" % error)
		http.queue_free()


func fetch_top_runs() -> void:
	var http := HTTPRequest.new()
	add_child(http)

	http.request_completed.connect(_on_top_runs_completed.bind(http))

	var url := (
		SUPABASE_URL.trim_suffix("/")
		+ "/rest/v1/run_records?select=player_name,kills,player_level,time_alive_seconds,score,created_at"
		+ "&order=score.desc,created_at.asc&limit=10"
	)

	var headers := PackedStringArray([
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + SUPABASE_KEY
	])

	var error := http.request(url, headers, HTTPClient.METHOD_GET)

	if error != OK:
		request_failed.emit("Could not start leaderboard request. Error: %s" % error)
		http.queue_free()


func _on_submit_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	_body: PackedByteArray,
	http: HTTPRequest
) -> void:
	http.queue_free()

	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		run_submitted.emit()
	else:
		request_failed.emit(
			"Score submission failed. HTTP: %s, request result: %s"
			% [response_code, result]
		)


func _on_top_runs_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	http: HTTPRequest
) -> void:
	http.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		request_failed.emit(
			"Leaderboard request failed. HTTP: %s, request result: %s"
			% [response_code, result]
		)
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())

	if not parsed is Array:
		request_failed.emit("The leaderboard response was not a JSON array.")
		return

	top_runs_loaded.emit(parsed)
