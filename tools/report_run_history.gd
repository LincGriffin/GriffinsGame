extends SceneTree
## Prints a summary of recorded runs (scripts/data/run_history.gd) — win rate, average
## battles/nodes, common causes of death, recruit frequency. For balance reference.
##
## Edit SOURCE below and run:
##   Godot_console.exe --headless --path <project> --script res://tools/report_run_history.gd

const RUN_HISTORY := preload("res://scripts/data/run_history.gd")

## "real" reads user://run_history.json (actual playthroughs); "simulated" reads
## user://run_history_simulated.json (tools/simulate_run.gd output).
const SOURCE := "simulated"


func _init() -> void:
	var path := RUN_HISTORY.REAL_PATH if SOURCE == "real" else RUN_HISTORY.SIMULATED_PATH
	var runs := RUN_HISTORY.load_all(path)
	if runs.is_empty():
		print("No recorded runs at ", path)
		quit()
		return

	var wins := 0
	var battles_total := 0
	var nodes_total := 0
	var deaths: Dictionary = {}       # enemy display name -> count
	var death_rows: Array = []        # died_at_row, losses only
	var starters: Dictionary = {}     # starter_id -> count
	var recruit_counts: Dictionary = {}   # monster id -> count

	for run in runs:
		if run.get("outcome") == "won":
			wins += 1
		else:
			var died_to: String = run.get("died_to", "")
			if died_to != "":
				deaths[died_to] = deaths.get(died_to, 0) + 1
			var row = run.get("died_at_row", -1)
			if row != null and int(row) >= 0:
				death_rows.append(int(row))
		battles_total += int(run.get("battles_fought", 0))
		nodes_total += int(run.get("nodes_resolved", 0))
		var sid: String = run.get("starter_id", "")
		if sid != "":
			starters[sid] = starters.get(sid, 0) + 1
		for rid in run.get("recruited", []):
			recruit_counts[rid] = recruit_counts.get(rid, 0) + 1

	var total := runs.size()
	print("=== Run history (%s): %d run(s) from %s ===" % [SOURCE, total, path])
	print("Win rate: %d/%d (%.1f%%)" % [wins, total, 100.0 * wins / total])
	print("Avg battles fought: %.1f" % (float(battles_total) / total))
	print("Avg nodes resolved: %.1f" % (float(nodes_total) / total))

	if not death_rows.is_empty():
		var row_sum := 0
		for r in death_rows:
			row_sum += r
		print("Avg row reached when lost: %.1f" % (float(row_sum) / death_rows.size()))

	if not deaths.is_empty():
		print("Top causes of death:")
		for name in _top(deaths, 5):
			print("  %s: %d" % [name, deaths[name]])

	if not starters.is_empty():
		print("Starters used:")
		for sid in _top(starters, 10):
			print("  %s: %d" % [sid, starters[sid]])

	if not recruit_counts.is_empty():
		print("Most-recruited monsters:")
		for rid in _top(recruit_counts, 10):
			print("  %s: %d" % [rid, recruit_counts[rid]])

	quit()


## Keys of `counts`, highest count first, capped at `limit`.
func _top(counts: Dictionary, limit: int) -> Array:
	var keys := counts.keys()
	keys.sort_custom(func(a, b): return counts[a] > counts[b])
	return keys.slice(0, limit)
