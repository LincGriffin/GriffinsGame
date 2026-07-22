extends "res://tools/tests/_base.gd"
## Moves: the move roster, monster movesets, and move-aware damage math (no scene).

func test_move_roster_present() -> void:
	var expected := {"strike": "attack", "heavy": "attack", "guard": "guard", "mend": "heal"}
	for id in expected:
		var mv = load("res://assets/data/moves/%s.tres" % id)
		check(mv != null and mv.id == id, "%s.tres exists with matching id" % id)
		eq(mv.kind, expected[id], "%s has kind %s" % [id, expected[id]])


func test_heavy_hits_harder_than_strike() -> void:
	var strike = load("res://assets/data/moves/strike.tres")
	var heavy = load("res://assets/data/moves/heavy.tres")
	check(heavy.power > strike.power, "heavy has more power than strike")


func test_monsters_have_movesets() -> void:
	var slime = load("res://assets/data/monsters/slime.tres")
	check(slime.moves.size() >= 2, "slime has at least two moves")
	var griffin = load("res://assets/data/monsters/griffin.tres")
	check(griffin.moves.size() >= 3, "the boss has a fuller kit")


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
