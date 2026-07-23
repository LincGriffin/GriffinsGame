extends SceneTree
## Headless full-run simulator — plays a complete run (starter pick through every reachable node
## to the boss) via RunHarness and prints a play-by-play log plus the final outcome. For manual
## validation/balance checks, not a replacement for actually playing the game.
##
## CAVEAT: RunHarness's default AI (_pick_move) always attacks — it never guards, heals, or
## switches proactively before a monster is in danger, only when forced by a faint. Treat any
## win rate this reports as a maximally-aggressive-play LOWER BOUND, not a difficulty benchmark:
## it's most useful for validating that the mechanics (recruiting, permadeath, node resolution)
## work correctly end-to-end, not as a literal "this is how hard the game is" measurement.
## Set RANDOM_MOVES to true for a different (also non-strategic) baseline: a uniformly random
## pick from the active monster's full moveset each turn, including guard/heal/buff/evade/
## reflect/stun/reckless — not just attack/drain — so the new move kinds actually get exercised.
##
## Edit STARTER_ID / RUNS / RANDOM_MOVES below and run:
##   Godot_console.exe --headless --path <project> --script res://tools/simulate_run.gd

const RUN_HARNESS := preload("res://tools/tests/run_harness.gd")
const MONSTERS_DIR := "res://assets/data/monsters/"

const STARTER_ID := "chicken"
const RUNS := 10         # bump for a bigger batch; win-rate summary always prints when > 1
const VERBOSE := true    # print the full play-by-play log for the first run
const RANDOM_MOVES := false   # see the CAVEAT above

var _wins := 0


func _init() -> void:
	_run()


func _run() -> void:
	var starter: MonsterData = load(MONSTERS_DIR + STARTER_ID + ".tres")
	for i in RUNS:
		var r := RUN_HARNESS.new(self)
		await r.play(starter, true, RANDOM_MOVES)
		if r.won:
			_wins += 1
		if VERBOSE and i == 0:
			_print_run(i, r)
		else:
			print("Run %d: %s (%d battles, %d nodes)" %
				[i + 1, "WON" if r.won else "LOST", r.battles_fought, r.nodes_resolved])
		r.teardown()
	if RUNS > 1:
		print("\n%d/%d runs won (%.1f%%)" % [_wins, RUNS, 100.0 * _wins / RUNS])
	quit()


func _print_run(i: int, r) -> void:
	print("=== Run %d: starting with %s ===" % [i + 1, STARTER_ID])
	for line in r.log:
		print("  ", line)
	print("--- Result: %s — %d battles, %d nodes resolved ---" %
		["WON" if r.won else "LOST", r.battles_fought, r.nodes_resolved])
