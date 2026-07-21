extends "res://tools/tests/_base.gd"
## Battle math + progression + content, as pure unit tests (no scene, no autoload).

func test_damage_attack_minus_half_defense() -> void:
	var a := Combatant.make("A", 20, 10, 0, 5)
	var b := Combatant.make("B", 20, 5, 4, 5)
	eq(Combatant.compute_damage(a, b), 8, "10 - floor(4/2) = 8")   # no rng => deterministic


func test_damage_never_below_one() -> void:
	var weak := Combatant.make("W", 10, 1, 0, 5)
	var tank := Combatant.make("T", 10, 5, 100, 5)
	eq(Combatant.compute_damage(weak, tank), 1, "damage floored at 1")


func test_defending_halves_damage() -> void:
	var a := Combatant.make("A", 20, 10, 0, 5)
	var b := Combatant.make("B", 20, 5, 0, 5)
	eq(Combatant.compute_damage(a, b), 10, "undefended hit")
	b.defending = true
	eq(Combatant.compute_damage(a, b), 5, "defending halves the hit")


func test_take_damage_clamps_to_zero() -> void:
	var c := Combatant.make("C", 10, 1, 1, 1)
	var dealt := c.take_damage(999)
	eq(c.hp, 0, "hp clamps to 0")
	eq(dealt, 10, "returns damage actually dealt")


func test_from_enemy_copies_stats() -> void:
	var griffin: EnemyData = load("res://assets/data/enemies/griffin.tres")
	check(griffin != null, "griffin.tres loads")
	check(griffin.is_boss, "griffin is flagged as the boss")
	var c := Combatant.from_enemy(griffin)
	eq(c.max_hp, griffin.max_hp, "combatant max_hp comes from data")
	eq(c.hp, griffin.max_hp, "combatant starts at full hp")
	check(c.is_boss, "combatant carries the boss flag")


func test_full_enemy_roster_present() -> void:
	for id in ["slime", "bat", "skeleton", "griffin"]:
		var e = load("res://assets/data/enemies/%s.tres" % id)
		check(e != null and e.id == id, "%s.tres exists with matching id" % id)


func test_gamestate_defaults() -> void:
	var gs = load("res://autoload/game_state.gd").new()
	eq(gs.level, 1, "starts at level 1")
	eq(gs.hp, 30, "starts with 30 hp")
	eq(gs.xp_to_next(), 10, "xp_to_next = level * 10")
	gs.free()


func test_gamestate_xp_below_threshold() -> void:
	var gs = load("res://autoload/game_state.gd").new()
	eq(gs.add_xp(5), 0, "no level gained from 5 xp")
	eq(gs.xp, 5, "xp accumulates")
	eq(gs.level, 1, "still level 1")
	gs.free()


func test_gamestate_level_up() -> void:
	var gs = load("res://autoload/game_state.gd").new()
	var base_attack: int = gs.attack
	eq(gs.add_xp(10), 1, "one level gained at the threshold")
	eq(gs.level, 2, "advanced to level 2")
	check(gs.attack > base_attack, "attack grew on level up")
	eq(gs.hp, gs.max_hp, "full heal on level up")
	gs.free()
