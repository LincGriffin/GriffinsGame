extends "res://tools/tests/_base.gd"
## RunHistory (scripts/data/run_history.gd) — runs entirely against a scratch user:// path so it
## never touches the real run_history.json / run_history_simulated.json files.

const RUN_HISTORY := preload("res://scripts/data/run_history.gd")
const TEST_PATH := "user://test_run_history.json"


func before_each() -> void:
	RUN_HISTORY.clear(TEST_PATH)


func after_each() -> void:
	RUN_HISTORY.clear(TEST_PATH)


func test_missing_file_loads_as_empty() -> void:
	eq(RUN_HISTORY.load_all(TEST_PATH), [], "no file yet -> empty history")


func test_record_and_load_round_trips() -> void:
	RUN_HISTORY.record({"starter_id": "chicken", "outcome": "won"}, TEST_PATH)
	var runs := RUN_HISTORY.load_all(TEST_PATH)
	eq(runs.size(), 1, "one recorded run")
	eq(runs[0]["starter_id"], "chicken", "fields round-trip through JSON")
	eq(runs[0]["outcome"], "won", "fields round-trip through JSON")
	check(runs[0].has("timestamp"), "record() stamps a timestamp")


func test_multiple_records_append_in_order() -> void:
	RUN_HISTORY.record({"outcome": "won"}, TEST_PATH)
	RUN_HISTORY.record({"outcome": "lost"}, TEST_PATH)
	RUN_HISTORY.record({"outcome": "won"}, TEST_PATH)
	var runs := RUN_HISTORY.load_all(TEST_PATH)
	eq(runs.size(), 3, "three recorded runs")
	eq(runs[0]["outcome"], "won", "oldest first")
	eq(runs[2]["outcome"], "won", "newest last")


func test_clear_empties_the_log() -> void:
	RUN_HISTORY.record({"outcome": "won"}, TEST_PATH)
	RUN_HISTORY.clear(TEST_PATH)
	eq(RUN_HISTORY.load_all(TEST_PATH), [], "clear() removes all recorded runs")


func test_corrupt_file_loads_as_empty_rather_than_erroring() -> void:
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string("not valid json {{{")
	f.close()
	eq(RUN_HISTORY.load_all(TEST_PATH), [], "a corrupt file is treated as empty, not a crash")


func test_real_and_simulated_paths_are_distinct() -> void:
	check(RUN_HISTORY.REAL_PATH != RUN_HISTORY.SIMULATED_PATH,
		"real playthroughs and simulated runs never share a log file")
