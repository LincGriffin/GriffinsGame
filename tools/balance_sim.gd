extends SceneTree
## Balance analysis: plays many full runs across several move-selection STRATEGIES and STARTERS
## (via RunHarness) and prints an aggregate report — win rate, average battles/nodes, how far losses
## get, and the biggest killers. All strategies are simple heuristics (no lookahead), so the win
## rates are a floor, not a skilled-player benchmark; the *relative* differences and the death
## causes are the useful signal.
##
##   Godot_console.exe --headless --path <project> --script res://tools/balance_sim.gd

const RUN_HARNESS := preload("res://tools/tests/run_harness.gd")
const MONSTERS := "res://assets/data/monsters/"

const STARTERS := ["chicken", "slime", "bat"]
const RUNS_PER := 10   # per strategy → 5 strategies × 10 = 50 runs
## When true, every won fight fuses the capture into a never-fused party member when one exists
## (the in-game post-capture merge offer, always taken) — a smaller party of stronger fused monsters.
const ALWAYS_MERGE := true


func _init() -> void:
	_run()


func _run() -> void:
	var strategies: Array = RUN_HARNESS.STRATEGIES
	var per := {}         # strategy -> aggregate dict
	var starters := {}    # starter id -> {wins,total}
	var deaths := {}      # "died_to" -> count
	var total := 0
	var total_wins := 0

	for strat in strategies:
		per[strat] = {"wins": 0, "total": 0, "battles": 0, "nodes": 0, "loss_rows": [], "party": 0}
		for i in RUNS_PER:
			var starter_id: String = STARTERS[i % STARTERS.size()]
			var r = RUN_HARNESS.new(self)
			await r.play(load(MONSTERS + starter_id + ".tres"), false, false, strat, ALWAYS_MERGE)
			var a: Dictionary = per[strat]
			a.total += 1
			a.battles += r.battles_fought
			a.nodes += r.nodes_resolved
			a.party += r.run_state.party.size()
			total += 1
			if not starters.has(starter_id):
				starters[starter_id] = {"wins": 0, "total": 0}
			starters[starter_id].total += 1
			if r.won:
				a.wins += 1
				total_wins += 1
				starters[starter_id].wins += 1
			else:
				a.loss_rows.append(r.died_at_row)
				deaths[r.died_to] = int(deaths.get(r.died_to, 0)) + 1
			print("  %-10s %d/%d  %-8s  %-4s  %2d battles  %2d nodes%s" % [
				strat, i + 1, RUNS_PER, starter_id, "WON" if r.won else "LOST",
				r.battles_fought, r.nodes_resolved,
				"" if r.won else "   died row %d to %s" % [r.died_at_row, r.died_to]])
			r.teardown()

	_report(strategies, per, starters, deaths, total, total_wins)
	quit()


func _report(strategies: Array, per: Dictionary, starters: Dictionary, deaths: Dictionary,
		total: int, total_wins: int) -> void:
	print("\n================ BALANCE REPORT (%d runs) ================" % total)
	print("Merge mode: %s" % ("ALWAYS merge captures when possible" if ALWAYS_MERGE else "never merge (recruit as-is)"))
	print("Overall win rate: %d/%d (%.1f%%)\n" % [total_wins, total, 100.0 * total_wins / total])

	print("By strategy:")
	print("  %-11s %-8s %-9s %-8s %-11s %-10s" %
		["strategy", "win%", "battles", "nodes", "avg loss row", "avg party"])
	for s in strategies:
		var a: Dictionary = per[s]
		var lr := "-"
		if not a.loss_rows.is_empty():
			var sum := 0
			for x in a.loss_rows:
				sum += int(x)
			lr = "%.1f" % (float(sum) / a.loss_rows.size())
		print("  %-11s %-8s %-9.1f %-8.1f %-11s %-10.1f" % [
			s, "%d%%" % roundi(100.0 * a.wins / a.total),
			float(a.battles) / a.total, float(a.nodes) / a.total, lr, float(a.party) / a.total])

	print("\nBy starter (across all strategies):")
	for id in STARTERS:
		if starters.has(id):
			var st: Dictionary = starters[id]
			print("  %-9s %d/%d (%d%%)" % [id, st.wins, st.total, roundi(100.0 * st.wins / st.total)])

	print("\nBiggest killers (who ended the run, all losses):")
	var pairs: Array = []
	for k in deaths:
		pairs.append([k, int(deaths[k])])
	pairs.sort_custom(func(x, y): return x[1] > y[1])
	for p in pairs:
		print("  %2d×  %s" % [p[1], p[0]])
	print("=========================================================")
