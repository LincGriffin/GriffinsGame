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

var run_state = null
var log: Array[String] = []
var won := false
var lost := false
var battles_fought := 0
var nodes_resolved := 0

var _tree: SceneTree
var _root: Node
var _run_ctrl   # detached Run instance — reused so node resolution never drifts from run.gd


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


## Play out one full run starting from `starter`. Stops early on a party wipe.
func play(starter: MonsterData) -> void:
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
			return
		await _resolve(node)
		nodes_resolved += 1
		if lost:
			return
	won = true


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
		var move_id := _pick_attack(h)
		if move_id == "":
			break
		await h.use_move(move_id)
		turns += 1
	battles_fought += 1
	run_state.prune_dead()
	var fainted: int = before - run_state.party.size()
	var kind: String = node["type"]
	match h.result:
		Battle.Result.PLAYER_WON:
			log.append("Row %d [%s]: defeated %s in %d turns.%s" % [node["row"], kind,
				enemy.display_name, turns,
				("  (%d party member(s) fainted this fight)" % fainted) if fainted > 0 else ""])
			if not enemy.is_boss:
				var recruited: bool = run_state.add_monster(enemy)
				if recruited:
					log.append("  Recruited %s! (party now %d: %s)" % [enemy.display_name,
						run_state.party.size(), _roster_summary()])
				if enemy.is_elite:
					_run_ctrl._heal_party()
					log.append("  Elite bonus: party fully healed.")
		Battle.Result.PLAYER_LOST:
			lost = true
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


## Prefer an offensive move (attack/drain); fall back to whatever the active monster knows.
func _pick_attack(h) -> String:
	var moves = h.battle._active.moves
	for mv in moves:
		if mv.kind == "attack" or mv.kind == "drain":
			return mv.id
	return moves[0].id if not moves.is_empty() else ""


func teardown() -> void:
	if run_state != null and is_instance_valid(run_state):
		_root.remove_child(run_state)
		run_state.free()
