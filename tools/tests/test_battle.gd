extends "res://tools/tests/_base.gd"
## Battle math + party/run-state + content, as pure unit tests (no scene, no autoload).

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


func test_from_monster_copies_stats() -> void:
	var hydra: MonsterData = load("res://assets/data/monsters/hydra.tres")
	check(hydra != null, "hydra.tres loads")
	check(hydra.is_boss, "the Hydra is flagged as the boss")
	var c := Combatant.from_monster(hydra)
	eq(c.max_hp, hydra.max_hp, "combatant max_hp comes from data")
	eq(c.hp, hydra.max_hp, "combatant starts at full hp")
	check(c.is_boss, "combatant carries the boss flag")
	eq(c.source, hydra, "combatant remembers its source data")


func test_full_monster_roster_present() -> void:
	for id in ["chicken", "slime", "bat", "rat", "skeleton", "goblin", "spider",
			"golem", "wraith", "gremlin_knob", "griffin", "hydra"]:
		var m = load("res://assets/data/monsters/%s.tres" % id)
		check(m != null and m.id == id, "%s.tres exists with matching id" % id)


func test_starter_flags() -> void:
	for id in ["chicken", "slime", "bat"]:
		var m = load("res://assets/data/monsters/%s.tres" % id)
		check(m.is_starter, "%s is a starter" % id)
		eq(m.tier, 0, "%s is a tier-0 (weakest) monster" % id)
	for id in ["skeleton", "griffin", "hydra"]:
		var m = load("res://assets/data/monsters/%s.tres" % id)
		check(not m.is_starter, "%s is not a starter" % id)


func test_elite_and_boss_flags() -> void:
	for id in ["gremlin_knob", "griffin"]:
		var m = load("res://assets/data/monsters/%s.tres" % id)
		check(m.is_elite, "%s is an elite" % id)
		check(not m.is_boss, "%s is not the boss" % id)
	var hydra = load("res://assets/data/monsters/hydra.tres")
	check(hydra.is_boss, "the Hydra is the boss")
	check(not hydra.is_elite, "the boss is not tagged elite")


func test_wild_tiers_span_a_range() -> void:
	# Depth scaling relies on wild monsters covering tiers 0..3.
	var tiers := {}
	for id in ["chicken", "rat", "goblin", "golem"]:
		var m = load("res://assets/data/monsters/%s.tres" % id)
		tiers[m.tier] = true
	for t in [0, 1, 2, 3]:
		check(tiers.has(t), "a wild monster exists at tier %d" % t)


# --- RunState: party / run lifecycle ---

func _new_run_state() -> Node:
	return load("res://autoload/run_state.gd").new()


func _slime() -> MonsterData:
	return load("res://assets/data/monsters/slime.tres")


func test_new_run_seeds_party_with_starter() -> void:
	var rs := _new_run_state()
	rs.new_run(_slime())
	eq(rs.party.size(), 1, "party seeded with the starter")
	eq(rs.party[0].hp, rs.party[0].max_hp, "starter enters at full hp")
	check(rs.has_living(), "a fresh run has a living party")
	rs.free()


func test_new_run_boosts_the_chosen_starter() -> void:
	var rs := _new_run_state()
	var slime := _slime()
	rs.new_run(slime)
	var c = rs.party[0]
	check(c.max_hp > slime.max_hp, "the starter's max hp is boosted above its base data")
	eq(c.hp, c.max_hp, "the boosted starter enters at full hp")
	check(c.attack > slime.attack, "the starter's attack is boosted above its base data")
	rs.free()


func test_add_monster_respects_cap() -> void:
	var rs := _new_run_state()
	rs.new_run(_slime())
	while not rs.is_full():
		check(rs.add_monster(_slime()), "add under cap succeeds")
	eq(rs.party.size(), rs.PARTY_CAP, "party filled to the cap")
	check(not rs.add_monster(_slime()), "add at cap is rejected")
	eq(rs.party.size(), rs.PARTY_CAP, "cap not exceeded")
	rs.free()


func test_prune_dead_removes_fallen() -> void:
	var rs := _new_run_state()
	rs.new_run(_slime())
	rs.add_monster(_slime())
	rs.party[0].hp = 0            # knock one out
	rs.prune_dead()
	eq(rs.party.size(), 1, "the fallen monster is pruned")
	check(rs.has_living(), "the survivor remains")
	rs.free()


func test_party_wipe_detected() -> void:
	var rs := _new_run_state()
	rs.new_run(_slime())
	rs.party[0].hp = 0
	check(not rs.has_living(), "no living monster after a wipe")
	rs.prune_dead()
	check(rs.party.is_empty(), "wiped party is empty after prune")
	rs.free()
