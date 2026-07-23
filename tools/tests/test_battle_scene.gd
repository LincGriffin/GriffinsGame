extends "res://tools/tests/_base.gd"
## Real end-to-end battle tests via BattleHarness — the first scene-level coverage battle.gd has
## ever had. Fixture monsters use deliberately lopsided stats (a 1-HP "weak" side, a 50+ HP
## "tank"/"brute" side) so win/lose/faint outcomes are guaranteed regardless of the ±1 damage
## variance or the enemy's random move pick, rather than trying to seed battle.gd's RNG (its
## _ready() unconditionally calls _rng.randomize(), so an externally-set seed wouldn't survive
## anyway). Exact damage numbers are already covered by test_battle.gd's pure compute_damage
## tests — these tests are about the STATE MACHINE (does the right thing happen), which is
## exactly what the recent Switch/Flee-hide changes touched.

const MONSTER_SCRIPT := preload("res://scripts/data/monster_data.gd")
const MOVE_SCRIPT := preload("res://scripts/data/move_data.gd")
const HARNESS := preload("res://tools/tests/battle_harness.gd")

var h  # BattleHarness


func before_each() -> void:
	h = HARNESS.new(runner)


func after_each() -> void:
	h.teardown()


func _move(id: String, power: int) -> MoveData:
	var mv: MoveData = MOVE_SCRIPT.new()
	mv.id = id
	mv.display_name = id.capitalize()
	mv.kind = "attack"
	mv.power = power
	return mv


func _monster(id: String, hp: int, atk: int, def: int, spd: int, mv: MoveData) -> MonsterData:
	var m: MonsterData = MONSTER_SCRIPT.new()
	m.id = id
	m.display_name = id.capitalize()
	m.max_hp = hp
	m.attack = atk
	m.defense = def
	m.speed = spd
	var moves: Array[MoveData] = [mv]
	m.moves = moves
	return m


func _weak(id: String) -> MonsterData:
	return _monster(id, 1, 1, 0, 1, _move("poke", 1))


func _tank(id: String) -> MonsterData:
	return _monster(id, 100, 10, 20, 5, _move("hit", 5))


func _brute(id: String) -> MonsterData:
	return _monster(id, 50, 10, 0, 10, _move("smash", 5))


func test_attack_defeats_a_weak_enemy_and_wins() -> void:
	var champ := _tank("champ")
	await h.start([champ], _weak("mite"))
	await h.use_move("hit")
	check(h.is_finished, "the battle ends")
	eq(h.result, Battle.Result.PLAYER_WON, "overwhelming the 1-hp enemy wins")


func test_party_wipe_loses() -> void:
	var runt := _weak("runt")
	await h.start([runt], _brute("ogre"))
	await h.use_move("poke")
	check(h.is_finished, "the battle ends")
	eq(h.result, Battle.Result.PLAYER_LOST, "the last (1-hp) monster fainting loses the run")


func test_voluntary_switch_changes_the_active_monster_and_costs_the_turn() -> void:
	await h.start([_tank("tank_a"), _tank("tank_b")], _weak("gnat"))
	eq(h.active_id(), "tank_a", "tank_a leads by default (party[0])")
	await h.switch_to("tank_b")
	check(not h.is_finished, "switching doesn't end the battle")
	eq(h.active_id(), "tank_b", "the switch changes the active monster")
	eq(h.run_state.party[0].hp, h.run_state.party[0].max_hp,
		"tank_a (switched OUT) took no damage — the enemy hit the new active monster instead")
	check(h.run_state.party[1].hp < h.run_state.party[1].max_hp,
		"tank_b (switched IN) took the enemy's turn")


func test_switch_cancel_costs_no_turn() -> void:
	await h.start([_tank("tank_a"), _tank("tank_b")], _weak("gnat"))
	await h.switch_to("")   # cancel
	check(not h.is_finished, "cancelling doesn't end the battle")
	eq(h.active_id(), "tank_a", "cancelling a switch leaves the original monster active")
	eq(h.run_state.party[0].hp, h.run_state.party[0].max_hp,
		"cancelling spends no turn — the enemy never got to act")


func test_forced_switch_on_faint_prompts_when_multiple_survivors() -> void:
	await h.start([_weak("weak_a"), _tank("tank_b"), _tank("tank_c")], _brute("ogre"))
	await h.use_move("poke")   # weak_a is slower than the brute, so the brute kills it first
	eq(h.last_prompt_options.size(), 2, "both survivors are offered when the leader faints")
	await h.resolve_prompt("tank_b")
	check(not h.is_finished, "the battle continues after the forced switch")
	eq(h.active_id(), "tank_b", "the chosen survivor becomes active")


func test_switch_not_offered_with_a_single_monster() -> void:
	await h.start([_tank("solo")], _weak("gnat"))
	check(not _button_texts().has("Switch"), "no Switch button with only one living monster")


func test_flee_is_hidden_by_default() -> void:
	await h.start([_tank("solo")], _weak("gnat"))
	check(not _button_texts().has("Flee"), "Flee is hidden while Battle.FLEE_ENABLED is false")
	check(not Battle.FLEE_ENABLED, "sanity: the toggle is actually off")


func _button_texts() -> Array:
	var out: Array = []
	for c in h.battle._actions.get_children():
		if c is Button:
			out.append(c.text)
	return out
