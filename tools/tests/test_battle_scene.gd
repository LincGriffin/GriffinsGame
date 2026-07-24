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


func _move(id: String, kind: String, power: int) -> MoveData:
	var mv: MoveData = MOVE_SCRIPT.new()
	mv.id = id
	mv.display_name = id.capitalize()
	mv.kind = kind
	mv.power = power
	return mv


func _monster(id: String, hp: int, atk: int, def: int, spd: int, moves: Array) -> MonsterData:
	var m: MonsterData = MONSTER_SCRIPT.new()
	m.id = id
	m.display_name = id.capitalize()
	m.max_hp = hp
	m.attack = atk
	m.defense = def
	m.speed = spd
	var typed: Array[MoveData] = []
	for mv in moves:
		typed.append(mv)
	m.moves = typed
	return m


func _weak(id: String) -> MonsterData:
	return _monster(id, 1, 1, 0, 1, [_move("poke", "attack", 1)])


func _tank(id: String) -> MonsterData:
	return _monster(id, 100, 10, 20, 5, [_move("hit", "attack", 5)])


func _brute(id: String) -> MonsterData:
	return _monster(id, 50, 10, 0, 10, [_move("smash", "attack", 5)])


## A fast (spd 20 — always outspeeds _brute) 100-hp monster with one basic attack plus the one
## new-kind move under test, so its own turn always resolves before the enemy's follow-up.
func _specialist(id: String, extra_kind: String, extra_id: String, extra_power: int) -> MonsterData:
	return _monster(id, 100, 10, 0, 20,
		[_move("hit", "attack", 5), _move(extra_id, extra_kind, extra_power)])


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


func test_evade_negates_the_next_hit() -> void:
	await h.start([_specialist("dodger", "evade", "dodge", 0)], _brute("ogre"))
	await h.use_move("dodge")
	check(not h.is_finished, "evading doesn't end the battle")
	eq(h.run_state.party[0].hp, h.run_state.party[0].max_hp,
		"the evading monster takes 0 damage from the enemy's follow-up attack")


func test_reflect_is_thorns_both_sides_take_the_damage() -> void:
	await h.start([_specialist("mirror_mon", "reflect", "bounce", 0)], _brute("ogre"))
	await h.use_move("bounce")
	check(not h.is_finished, "reflecting doesn't end the battle — both are 100-hp")
	check(h.run_state.party[0].hp < h.run_state.party[0].max_hp,
		"the reflecting monster STILL takes the damage (reflect no longer prevents it)")
	check(h.battle._enemy.hp < h.battle._enemy.max_hp,
		"the enemy also takes the same damage reflected back (thorns)")


func test_stun_lands_and_skips_the_enemy_turn() -> void:
	await h.start([_specialist("zapper", "stun", "zap", 4)], _brute("ogre"))
	h.battle.STUN_CHANCE = 1.0   # force the 50% stun to land, for a deterministic outcome
	await h.use_move("zap")
	check(not h.is_finished, "stunning doesn't end the battle")
	check(h.battle._enemy.hp < h.battle._enemy.max_hp, "the stun attack itself still deals damage")
	eq(h.run_state.party[0].hp, h.run_state.party[0].max_hp,
		"the stunned enemy's turn is skipped, so the stunner takes no counter-damage")


func test_stun_can_miss() -> void:
	await h.start([_specialist("zapper", "stun", "zap", 4)], _brute("ogre"))
	h.battle.STUN_CHANCE = 0.0   # force the stun to fail
	await h.use_move("zap")
	check(h.run_state.party[0].hp < h.run_state.party[0].max_hp,
		"when the stun fails the enemy still acts, so the player takes a counter-hit")


func test_guard_grants_a_counter_bonus_consumed_by_the_next_attack() -> void:
	await h.start([_specialist("bracer", "guard", "brace", 0)], _brute("ogre"))
	await h.use_move("brace")   # guard → sets a one-shot counter bonus
	eq(h.battle._active.counter_bonus, h.battle.COUNTER_ATK, "guard sets a one-shot counter bonus")
	await h.use_move("hit")     # the specialist's basic attack consumes it
	eq(h.battle._active.counter_bonus, 0, "the counter bonus is consumed by the next attack")


func test_reckless_damages_both_sides() -> void:
	await h.start([_specialist("berserker", "reckless", "wild", 14)], _weak("mite"))
	await h.use_move("wild")
	check(h.is_finished, "a reckless hit still one-shots a 1-hp enemy")
	eq(h.result, Battle.Result.PLAYER_WON, "the enemy goes down despite the user's own recoil")
	check(h.run_state.party[0].hp < h.run_state.party[0].max_hp,
		"the user still takes recoil damage even though the enemy was defeated")
