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


func test_cooldown_blocks_reuse_for_one_turn_then_expires() -> void:
	var c := Combatant.make("c", 20, 5, 0, 5)
	check(not c.on_cooldown("slam"), "a move starts off cooldown")
	c.start_cooldown("slam", 1)          # used a 1-turn-cooldown move
	c.tick_cooldowns()                    # the caster's next turn begins
	check(c.on_cooldown("slam"), "still on cooldown the very next turn (can't be used)")
	c.tick_cooldowns()                    # the turn after
	check(not c.on_cooldown("slam"), "available again the following turn")


func test_zero_cooldown_never_blocks() -> void:
	var c := Combatant.make("c", 20, 5, 0, 5)
	c.start_cooldown("strike", 0)         # the basic attack has cooldown 0
	c.tick_cooldowns()
	check(not c.on_cooldown("strike"), "a 0-cooldown move is never blocked")


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
	check(c.defense > slime.defense, "the starter's defense is boosted above its base data")
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


func test_serialize_restore_preserves_live_party() -> void:
	# Save/resume scaffold: the party round-trips its FULL live state, not just monster ids.
	var rs := _new_run_state()
	rs.new_run(_slime())
	rs.add_monster(load("res://assets/data/monsters/bat.tres"))
	rs.party[0].attack += 5       # simulate a power-up diverging from base stats
	rs.party[0].hp = 3            # mid-run HP
	var names: Array = []
	var stats: Array = []
	for c in rs.party:
		names.append(c.display_name)
		stats.append([c.max_hp, c.hp, c.attack, c.defense])
	var data: Array = rs.serialize_party()
	rs.free()

	var rs2 := _new_run_state()
	rs2.restore_party(data)
	eq(rs2.party.size(), 2, "restored party has the same number of monsters")
	for i in rs2.party.size():
		var c = rs2.party[i]
		eq(c.display_name, names[i], "monster %d name preserved" % i)
		eq([c.max_hp, c.hp, c.attack, c.defense], stats[i], "monster %d live stats preserved" % i)
		check(c.source != null, "restored monster has a source (for portrait/art lookup)")
		check(c.moves.size() > 0, "restored monster keeps its moves")
	rs2.free()


func test_merge_incoming_fuses_capture_with_a_partner() -> void:
	# The post-capture offer: fuse a NEWLY CAPTURED monster (not in the party) with an existing
	# partner. Party size is unchanged — the capture is spent into the fusion, the partner replaced.
	var rs := _new_run_state()
	rs.new_run(_slime())
	rs.add_monster(load("res://assets/data/monsters/bat.tres"))
	var before: int = rs.party.size()
	var partner = rs.party[1]   # the bat
	var fused = rs.merge_incoming(partner, load("res://assets/data/monsters/goblin.tres"))
	eq(rs.party.size(), before, "party size is unchanged (capture consumed, partner replaced)")
	check(not rs.party.has(partner), "the chosen partner was replaced")
	check(rs.party.has(fused), "the fused monster is in the party")
	check(fused.is_fused, "the result is flagged fused")
	rs.free()


func test_unfused_living_excludes_fused_members() -> void:
	var rs := _new_run_state()
	rs.new_run(_slime())
	rs.add_monster(load("res://assets/data/monsters/bat.tres"))
	rs.merge_incoming(rs.party[1], load("res://assets/data/monsters/goblin.tres"))  # party[1] -> fused
	var unfused: Array = rs.unfused_living()
	check(unfused.size() == 1 and not unfused[0].is_fused, "only the never-fused starter is eligible")
	rs.free()


func test_serialize_restore_rebuilds_a_fused_monster() -> void:
	# The hard case: a merged monster's MonsterData is generated at run time with NO file on disk,
	# so restore must rebuild it from the saved fields rather than loading an id.
	var rs := _new_run_state()
	rs.new_run(_slime())
	rs.add_monster(load("res://assets/data/monsters/bat.tres"))
	var fused = rs.merge(rs.party[0], rs.party[1])
	eq(rs.party.size(), 1, "merge left a single fused monster")
	var fused_name: String = fused.display_name
	var fused_stats: Array = [fused.max_hp, fused.attack, fused.defense]
	var fused_moves: int = fused.moves.size()
	var data: Array = rs.serialize_party()
	rs.free()

	var rs2 := _new_run_state()
	rs2.restore_party(data)
	eq(rs2.party.size(), 1, "the fused monster round-trips")
	var c = rs2.party[0]
	eq(c.display_name, fused_name, "fused monster's name preserved (no on-disk source needed)")
	eq([c.max_hp, c.attack, c.defense], fused_stats, "fused monster's stats preserved")
	eq(c.moves.size(), fused_moves, "fused monster's merged moveset preserved")
	check(c.source != null, "restored fused monster still has a (synthetic) source for tint fallback")
	check(c.is_fused, "the is_fused flag round-trips (so a resumed run keeps merge eligibility right)")
	rs2.free()


func test_party_wipe_detected() -> void:
	var rs := _new_run_state()
	rs.new_run(_slime())
	rs.party[0].hp = 0
	check(not rs.has_living(), "no living monster after a wipe")
	rs.prune_dead()
	check(rs.party.is_empty(), "wiped party is empty after prune")
	rs.free()
