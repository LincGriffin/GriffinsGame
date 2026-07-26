class_name RunHarness
extends RefCounted
## Plays out a FULL simulated run headlessly — starter pick through every reachable node to the
## boss — by reusing run.gd's own node-resolution logic (via a detached Run instance, same
## approach test_run.gd uses) for heal/powerup/room nodes, and BattleHarness for every fight.
## Built for manual validation / balance checks; see tools/simulate_run.gd for a runnable tool.
##
## The dungeon is fully open and connected (see dungeon_view.gd), so "play the run" here means
## resolving every node in row order (row 0 first, boss last — always safe since edges only ever
## point to a higher row) rather than modeling the player's literal walking path. That's a
## thorough/completionist run (every heal, power-up, and recruit along the way), not a beeline to
## the boss — real players with full backtrack access can do the same.
##
## `tree` must be the actual SceneTree, same requirement as BattleHarness (see its docstring for
## why — calling .get_tree() on a Node near a --script SceneTree's own _init() returns null).
##
## Usage:
##   var r := RunHarness.new(tree)
##   await r.play(load("res://assets/data/monsters/chicken.tres"))
##   print(r.won, r.log)
##   r.teardown()

const RUN_STATE_SCRIPT := preload("res://autoload/run_state.gd")
const RUN_SCRIPT := preload("res://scripts/run.gd")
const MAP_GENERATOR := preload("res://scripts/map/map_generator.gd")
const BATTLE_HARNESS := preload("res://tools/tests/battle_harness.gd")
const RUN_HISTORY := preload("res://scripts/data/run_history.gd")

var run_state = null
var log: Array[String] = []
var won := false
var lost := false
var battles_fought := 0
var nodes_resolved := 0
var died_to := ""
var died_at_row := -1
var recruited: Array[String] = []

var _tree: SceneTree
var _root: Node
var _run_ctrl   # detached Run instance — reused so node resolution never drifts from run.gd
var _random_moves := false   # see play()'s random_moves param
var _strategy := "aggressive"   # move-selection AI; see _pick_move() / STRATEGIES

## The move-selection strategies balance-sim can play (a *different* non-strategic-to-strategic
## spread, all still simple heuristics — no lookahead). See _pick_move().
const STRATEGIES := ["aggressive", "burst", "defensive", "support", "random"]


func _init(tree: SceneTree) -> void:
	_tree = tree
	_root = tree.root
	run_state = RUN_STATE_SCRIPT.new()
	run_state.name = "RunState"
	_root.add_child(run_state)
	_run_ctrl = RUN_SCRIPT.new()
	_run_ctrl._gs = run_state
	_run_ctrl._rng.randomize()
	_run_ctrl._build_wild_index()


## Play out one full run starting from `starter`. Stops early on a party wipe. Records to
## RunHistory.SIMULATED_PATH (scripts/data/run_history.gd) unless `record_history` is false —
## keep it on for real balance-simulation runs, turn it off for anything that shouldn't pollute
## the log (e.g. a future automated test exercising RunHarness itself). `random_moves` picks a
## uniformly random move each turn (from the active monster's FULL moveset — guard/heal/buff/
## evade/reflect/stun/reckless included, not just attack/drain) instead of the default
## always-prefer-offense heuristic; see _pick_move().
func play(starter: MonsterData, record_history := true, random_moves := false,
		strategy := "") -> void:
	_random_moves = random_moves
	_strategy = strategy if strategy != "" else ("random" if random_moves else "aggressive")
	var starter_id := String(starter.id)
	run_state.new_run(starter)
	log.append("Starter: %s (HP %d, ATK %d)" % [
		starter.display_name, run_state.party[0].max_hp, run_state.party[0].attack])

	var map: Dictionary = MAP_GENERATOR.new().generate(_run_ctrl._rng)
	_run_ctrl._map = map
	_run_ctrl._assign_encounters()

	var nodes: Array = map["nodes"].duplicate()
	nodes.sort_custom(func(a, b): return a["row"] < b["row"])

	for node in nodes:
		if not run_state.has_living():
			lost = true
			log.append("Party already wiped — stopping before row %d." % node["row"])
			break
		await _resolve(node)
		nodes_resolved += 1
		if lost:
			break
	if not lost:
		won = true
	if record_history:
		RUN_HISTORY.record(_build_record(starter_id), RUN_HISTORY.SIMULATED_PATH)


## See scripts/data/run_history.gd for the record shape convention.
func _build_record(starter_id: String) -> Dictionary:
	var final_party: Array = []
	for c in run_state.party:
		final_party.append({
			"id": String(c.source.id) if c.source != null else "",
			"display_name": c.display_name,
			"hp": c.hp,
			"max_hp": c.max_hp,
		})
	return {
		"starter_id": starter_id,
		"outcome": "won" if won else "lost",
		"nodes_resolved": nodes_resolved,
		"battles_fought": battles_fought,
		"died_to": died_to,
		"died_at_row": died_at_row,
		"recruited": recruited,
		"final_party": final_party,
	}


func _resolve(node: Dictionary) -> void:
	match node["type"]:
		"battle", "elite", "boss":
			await _fight(node)
		"heal":
			_run_ctrl._heal_party()
			log.append("Row %d [heal]: party fully healed." % node["row"])
		"powerup":
			var learner_before := _knows_everything()
			_run_ctrl._apply_powerup()
			if learner_before:
				log.append("Row %d [powerup]: roster full of moves — +%d max HP instead." %
					[node["row"], _run_ctrl.POWERUP_HP])
			else:
				log.append("Row %d [powerup]: a monster learned a new move." % node["row"])
		"room":
			_run_ctrl._grant_treasure()
			log.append("Row %d [room]: treasure — +%d max HP for the whole party." %
				[node["row"], _run_ctrl.ROOM_BONUS_HP])
		"teleport":
			log.append("Row %d [teleport]: warp pad (no direct effect when resolving in place)." %
				node["row"])
		_:
			log.append("Row %d [%s]: nothing to resolve." % [node["row"], node["type"]])


func _knows_everything() -> bool:
	for c in run_state.living():
		for mv in _run_ctrl.MOVE_POOL:
			if not _run_ctrl._knows(c, mv):
				return false
	return true


func _fight(node: Dictionary) -> void:
	var enemy: MonsterData = node["enemy"]
	var before: int = run_state.party.size()
	var h := BATTLE_HARNESS.new(_tree)
	await h.start([], enemy, "", true, false)   # reset_party=false: fight with the run's actual party
	var turns := 0
	while not h.is_finished and turns < 200:
		if h.last_beat == BATTLE_HARNESS.Beat.PROMPT:
			await h.resolve_prompt(String(h.last_prompt_options[0].source.id))
			continue
		var move_id := _pick_move(h)
		if move_id == "":
			break
		await h.use_move(move_id)
		turns += 1
	battles_fought += 1
	# A fight that never resolves in 200 turns (e.g. a defensive monster out-sustaining the enemy)
	# is a stalemate, not a win — count it as a loss so it can't inflate a strategy's win rate.
	if not h.is_finished:
		run_state.prune_dead()
		lost = true
		died_to = "%s (stalemate)" % enemy.display_name
		died_at_row = int(node["row"])
		log.append("Row %d [%s]: stalemate vs %s (200 turns). Run over." %
			[int(node["row"]), String(node["type"]), enemy.display_name])
		h.teardown()
		return
	run_state.prune_dead()
	var fainted: int = before - run_state.party.size()
	var kind: String = node["type"]
	match h.result:
		Battle.Result.PLAYER_WON:
			log.append("Row %d [%s]: defeated %s in %d turns.%s" % [node["row"], kind,
				enemy.display_name, turns,
				("  (%d party member(s) fainted this fight)" % fainted) if fainted > 0 else ""])
			if not enemy.is_boss:
				var did_recruit: bool = run_state.add_monster(enemy)
				if did_recruit:
					recruited.append(String(enemy.id))
					log.append("  Recruited %s! (party now %d: %s)" % [enemy.display_name,
						run_state.party.size(), _roster_summary()])
				if enemy.is_elite:
					_run_ctrl._heal_party()
					log.append("  Elite bonus: party fully healed.")
		Battle.Result.PLAYER_LOST:
			lost = true
			died_to = enemy.display_name
			died_at_row = int(node["row"])
			log.append("Row %d [%s]: lost to %s after %d turns. Run over." %
				[node["row"], kind, enemy.display_name, turns])
		Battle.Result.FLED:
			log.append("Row %d [%s]: fled from %s." % [node["row"], kind, enemy.display_name])
	h.teardown()


func _roster_summary() -> String:
	var parts: Array[String] = []
	for c in run_state.party:
		parts.append("%s %d/%d" % [c.display_name, c.hp, c.max_hp])
	return ", ".join(parts)


## Pick the active monster's move for this turn per `_strategy`. All heuristics, no lookahead:
##  aggressive — first offensive move (attack/drain); the original baseline.
##  burst      — the highest-power damaging move (attack/drain/reckless/stun).
##  defensive  — heal (or guard) when below 45% HP, otherwise attack.
##  support    — open with a buff (once, while atk_bonus is 0), prefer drain, otherwise attack.
##  random     — uniformly random from the FULL moveset (guard/heal/buff/evade/reflect/... included).
func _pick_move(h) -> String:
	var active = h.battle._active
	# Only pick from moves that aren't on cooldown (the command menu would grey them out); fall
	# back to the full moveset if somehow everything is cooling down (matches battle's safety).
	var moves: Array = active.moves.filter(func(mv): return not active.on_cooldown(mv.id))
	if moves.is_empty():
		moves = active.moves
	if moves.is_empty():
		return ""
	match _strategy:
		"random":
			return moves[_run_ctrl._rng.randi_range(0, moves.size() - 1)].id
		"burst":
			return _best_damage_move(moves)
		"defensive":
			if float(active.hp) / maxf(1.0, float(active.max_hp)) < 0.45:
				var heal := _first_kind(moves, "heal")
				if heal != "":
					return heal
				var guard := _first_kind(moves, "guard")
				if guard != "":
					return guard
			return _offense(moves)
		"support":
			if active.atk_bonus == 0:
				var buff := _first_kind(moves, "buff")
				if buff != "":
					return buff
			var drain := _first_kind(moves, "drain")
			if drain != "":
				return drain
			return _offense(moves)
		_:   # aggressive
			return _offense(moves)


## First offensive move (attack/drain), else the first known move.
func _offense(moves: Array) -> String:
	for mv in moves:
		if mv.kind == "attack" or mv.kind == "drain":
			return mv.id
	return moves[0].id


## Highest-power damage-dealing move (attack/drain/reckless/stun), else the first known move.
func _best_damage_move(moves: Array) -> String:
	var best_id := ""
	var best_power := -1
	for mv in moves:
		if mv.kind in ["attack", "drain", "reckless", "stun"] and mv.power > best_power:
			best_power = mv.power
			best_id = mv.id
	return best_id if best_id != "" else moves[0].id


func _first_kind(moves: Array, kind: String) -> String:
	for mv in moves:
		if mv.kind == kind:
			return mv.id
	return ""


func teardown() -> void:
	if run_state != null and is_instance_valid(run_state):
		_root.remove_child(run_state)
		run_state.free()
