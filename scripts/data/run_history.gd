class_name RunHistory
extends RefCounted
## Persistent record of past runs — outcome, how far you got, what beat you, final roster.
## Written by `run.gd` (real playthroughs, `REAL_PATH`) and `tools/tests/run_harness.gd` /
## `tools/simulate_run.gd` (simulated runs, `SIMULATED_PATH`) — two separate logs sharing one
## record shape, kept apart so Monte Carlo noise never mixes with real player history.
##
## Right now this is dev-facing (balance reference via `tools/report_run_history.gd`); the same
## file/shape could back an in-game "Run History" screen later with no format changes.
##
## A record is a plain Dictionary. By convention: `timestamp` (stamped by `record()`),
## `starter_id`, `outcome` ("won"/"lost"), `nodes_resolved`, `battles_fought`, `died_to`
## (enemy display name, "" if won), `died_at_row` (-1 if won), `recruited` (Array[String] of
## monster ids), `final_party` (Array of {id, display_name, hp, max_hp}).

const REAL_PATH := "user://run_history.json"
const SIMULATED_PATH := "user://run_history_simulated.json"


## Append one run's summary to the log at `path`, stamping the current time.
static func record(entry: Dictionary, path: String = REAL_PATH) -> void:
	entry["timestamp"] = Time.get_datetime_string_from_system()
	var history := load_all(path)
	history.append(entry)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(history, "  "))
	f.close()


## All recorded runs at `path`, oldest first. Empty if the file doesn't exist yet, or is corrupt.
static func load_all(path: String = REAL_PATH) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Array else []


## Erase the log at `path` (mainly for tests, or a player choosing to reset their history later).
static func clear(path: String = REAL_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
