extends "res://tools/tests/_base.gd"
## Moves: the move roster, monster movesets, and move-aware damage math (no scene).

func test_move_roster_present() -> void:
	var expected := {
		"strike": "attack", "heavy": "attack", "slam": "attack",
		"guard": "guard", "evade": "evade", "reflect": "reflect",
		"mend": "heal", "drain": "drain", "focus": "buff",
		"shock": "stun", "reckless_swing": "reckless",
	}
	for id in expected:
		var mv = load("res://assets/data/moves/%s.tres" % id)
		check(mv != null and mv.id == id, "%s.tres exists with matching id" % id)
		eq(mv.kind, expected[id], "%s has kind %s" % [id, expected[id]])


func test_only_the_basic_strike_is_cooldown_free() -> void:
	eq(load("res://assets/data/moves/strike.tres").cooldown, 0, "the basic Strike has no cooldown")
	for id in ["heavy", "slam", "guard", "evade", "reflect", "mend", "drain", "focus", "shock",
			"reckless_swing"]:
		check(load("res://assets/data/moves/%s.tres" % id).cooldown >= 1,
			"%s (a non-basic move) has a cooldown" % id)


func test_moves_default_to_not_charging() -> void:
	# Charge is an opt-in per-move capability; nothing in the shipped roster charges by default.
	for id in ["strike", "heavy", "slam", "guard", "mend", "shock"]:
		check(not load("res://assets/data/moves/%s.tres" % id).charge,
			"%s does not charge by default" % id)


func test_moves_carry_optional_effect_ids() -> void:
	# Every move exposes sfx/vfx (default blank), and the example-assigned effects are present.
	var mend = load("res://assets/data/moves/mend.tres")
	check(mend.sfx == "", "an un-overridden move has a blank sfx (falls back to move_<kind>)")
	eq(mend.vfx, "heal_sparkle", "mend carries its example vfx id")
	var guard = load("res://assets/data/moves/guard.tres")
	eq(guard.vfx, "", "a move with no assigned effect has a blank vfx")


func test_moves_can_share_a_vfx() -> void:
	# Sharing is the whole point of referencing by id — strike and heavy both reuse "slash".
	var strike = load("res://assets/data/moves/strike.tres")
	var heavy = load("res://assets/data/moves/heavy.tres")
	eq(strike.vfx, "slash", "strike uses the slash effect")
	eq(heavy.vfx, strike.vfx, "heavy shares the same effect id (no duplicate asset)")


func test_heavy_hits_harder_than_strike() -> void:
	var strike = load("res://assets/data/moves/strike.tres")
	var heavy = load("res://assets/data/moves/heavy.tres")
	var slam = load("res://assets/data/moves/slam.tres")
	check(heavy.power > strike.power, "heavy has more power than strike")
	check(slam.power > heavy.power, "slam hits harder still")


func test_reckless_swing_hits_harder_than_slam() -> void:
	var slam = load("res://assets/data/moves/slam.tres")
	var reckless = load("res://assets/data/moves/reckless_swing.tres")
	check(reckless.power > slam.power, "reckless swing trades safety for the hardest hit in the game")


func test_monsters_have_movesets() -> void:
	var slime = load("res://assets/data/monsters/slime.tres")
	check(slime.moves.size() >= 2, "slime has at least two moves")
	var hydra = load("res://assets/data/monsters/hydra.tres")
	check(hydra.moves.size() >= 4, "the boss has a fuller kit")


func test_atk_bonus_raises_damage() -> void:
	# The "buff" mechanic works by adding to atk_bonus, which compute_damage folds in.
	var a := Combatant.make("A", 20, 10, 0, 5)
	var b := Combatant.make("B", 20, 5, 0, 5)
	eq(Combatant.compute_damage(a, b, null, 0), 10, "base damage before a buff")
	a.atk_bonus = 3
	eq(Combatant.compute_damage(a, b, null, 0), 13, "atk_bonus adds to the damage")


func test_from_monster_copies_moves() -> void:
	var slime = load("res://assets/data/monsters/slime.tres")
	var original: int = slime.moves.size()
	var c := Combatant.from_monster(slime)
	eq(c.moves.size(), original, "combatant carries the monster's moves")
	# The copy is independent — granting the combatant a move must not touch the resource.
	c.moves.append(load("res://assets/data/moves/mend.tres"))
	eq(c.moves.size(), original + 1, "combatant's moves grew")
	eq(slime.moves.size(), original, "the MonsterData resource is untouched")


func test_move_power_increases_damage() -> void:
	var a := Combatant.make("A", 20, 10, 0, 5)
	var b := Combatant.make("B", 20, 5, 0, 5)
	eq(Combatant.compute_damage(a, b, null, 0), 10, "base damage = attack - floor(def/2)")
	eq(Combatant.compute_damage(a, b, null, 5), 15, "move power adds to the damage")
