extends SceneTree
## Headless battle simulator — runs many battles between a party and an enemy via
## BattleHarness and reports win/loss/turn stats. For manual balance/functionality checks
## outside the automated test suite (e.g. "does a fresh Chicken have a reasonable shot against a
## mid-game Goblin?"). Uses a simple "always attack, auto-resolve forced switches" AI — good
## enough to gauge raw matchup difficulty, not a substitute for actually playing it.
##
## Edit PARTY_IDS / ENEMY_ID / BATTLES below and run:
##   Godot_console.exe --headless --path <project> --script res://tools/simulate_battle.gd

const HARNESS := preload("res://tools/tests/battle_harness.gd")
const MONSTERS_DIR := "res://assets/data/monsters/"

const PARTY_IDS := ["chicken", "slime", "bat"]   # party[0] gets the starter boost, same as a real run
const ENEMY_ID := "goblin"
const BATTLES := 200
const TURN_CAP := 200            # safety net against an unexpected stalemate

var _wins := 0
var _losses := 0
var _flees := 0
var _turns_total := 0
var _capped := 0


func _init() -> void:
	_run()


func _run() -> void:
	var party: Array = []
	for id in PARTY_IDS:
		party.append(_load(id))
	var enemy := _load(ENEMY_ID)
	for i in BATTLES:
		await _simulate_one(party, enemy)
	_report()
	quit()


func _load(id: String) -> MonsterData:
	var m: MonsterData = load(MONSTERS_DIR + id + ".tres")
	assert(m != null, "no monster with id \"%s\"" % id)
	return m


func _simulate_one(party: Array, enemy: MonsterData) -> void:
	var h := HARNESS.new(self)
	await h.start(party, enemy)
	var turns := 0
	while not h.is_finished and turns < TURN_CAP:
		if h.last_beat == HARNESS.Beat.PROMPT:
			var pick = h.last_prompt_options[0]
			await h.resolve_prompt(String(pick.source.id))
			continue
		var move_id := _pick_attack(h)
		if move_id == "":
			break
		await h.use_move(move_id)
		turns += 1
	if not h.is_finished:
		_capped += 1
	_turns_total += turns
	match h.result:
		Battle.Result.PLAYER_WON:
			_wins += 1
		Battle.Result.PLAYER_LOST:
			_losses += 1
		Battle.Result.FLED:
			_flees += 1
	h.teardown()


## Prefer an offensive move (attack/drain); fall back to whatever the active monster knows.
func _pick_attack(h) -> String:
	var moves = h.battle._active.moves
	for mv in moves:
		if mv.kind == "attack" or mv.kind == "drain":
			return mv.id
	return moves[0].id if not moves.is_empty() else ""


func _report() -> void:
	print("Simulated %d battles: %s vs %s" % [BATTLES, str(PARTY_IDS), ENEMY_ID])
	print("  wins:   %d (%.1f%%)" % [_wins, 100.0 * _wins / BATTLES])
	print("  losses: %d (%.1f%%)" % [_losses, 100.0 * _losses / BATTLES])
	print("  fled:   %d (%.1f%%)" % [_flees, 100.0 * _flees / BATTLES])
	if _capped > 0:
		print("  WARNING: %d battle(s) hit the %d-turn safety cap without finishing" % [_capped, TURN_CAP])
	print("  avg turns: %.1f" % (float(_turns_total) / BATTLES))
