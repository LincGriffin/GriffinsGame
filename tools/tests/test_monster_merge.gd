extends "res://tools/tests/_base.gd"
## Monster merge (Phase 6): the pure fusion rules (MonsterMerge / FusionTable) and RunState.merge.

const MERGE := preload("res://scripts/monster_merge.gd")
const FUSION := preload("res://scripts/data/fusion_table.gd")
const COMBATANT := preload("res://scripts/battle/combatant.gd")
const MOVE_DATA := preload("res://scripts/data/move_data.gd")
const MONSTER_DATA := preload("res://scripts/data/monster_data.gd")


func _mk(id: String, hp: int, atk: int, def: int, spd: int, move_ids: Array, tier := 0) -> Combatant:
	var md = MONSTER_DATA.new()
	md.id = id
	md.display_name = id.capitalize()
	md.max_hp = hp
	md.attack = atk
	md.defense = def
	md.speed = spd
	md.tier = tier
	var moves: Array[MoveData] = []   # must be typed — MonsterData.moves is Array[MoveData]
	for mid in move_ids:
		var mv = MOVE_DATA.new()
		mv.id = mid
		mv.display_name = String(mid).capitalize()
		mv.kind = "attack"
		mv.power = 3
		moves.append(mv)
	md.moves = moves
	return COMBATANT.from_monster(md)


func test_fuse_marks_a_generic_result_fused() -> void:
	var a := _mk("aa", 20, 8, 3, 5, ["x"])
	var b := _mk("bb", 14, 4, 6, 9, ["y"])
	check(not a.is_fused and not b.is_fused, "fresh parents are not fused")
	var f := MERGE.fuse(a, b)   # "aa|bb" is not a table pair -> generic, a dead end
	check(f.is_fused, "a generic fused result is flagged is_fused (never an eligible partner again)")


func test_unfused_filter_excludes_fused() -> void:
	# The never-fused-only eligibility rule the offer uses.
	var a := _mk("aa", 20, 8, 3, 5, ["x"])
	var b := _mk("bb", 14, 4, 6, 9, ["y"])
	var f := MERGE.fuse(a, b)
	var party := [a, b, f]
	var unfused := party.filter(func(c): return not c.is_fused)
	eq(unfused.size(), 2, "only the two never-fused monsters are eligible partners")
	check(not unfused.has(f), "the fused monster is excluded")


func test_stats_are_per_stat_max_plus_bonus() -> void:
	var a := _mk("aa", 20, 8, 3, 5, ["x"])
	var b := _mk("bb", 14, 4, 6, 9, ["y"])
	var f := MERGE.fuse(a, b)
	eq(f.max_hp, int(ceil(20 * MERGE.HP_MULT)), "hp = ceil(higher max_hp * HP_MULT)")
	eq(f.hp, f.max_hp, "fused starts at full HP")
	eq(f.attack, 8 + MERGE.ATK_BONUS, "attack = higher parent's + bonus")
	eq(f.defense, 6 + MERGE.DEF_BONUS, "defense = higher parent's + bonus")
	check(f.max_hp < a.max_hp + b.max_hp, "hp is NOT the additive sum of both parents")


func test_moves_are_union_deduped() -> void:
	var a := _mk("aa", 10, 5, 2, 5, ["strike", "guard"])
	var b := _mk("bb", 10, 5, 2, 5, ["guard", "drain"])
	var f := MERGE.fuse(a, b)
	var ids := []
	for m in f.moves:
		ids.append(m.id)
	eq(ids.size(), 3, "union of {strike,guard} and {guard,drain} has 3 unique moves")
	check(ids.has("strike") and ids.has("guard") and ids.has("drain"),
		"union covers both movesets with the duplicate collapsed")


func test_moves_are_capped() -> void:
	var many := ["m1", "m2", "m3", "m4"]
	var a := _mk("aa", 10, 5, 2, 5, many)
	var b := _mk("bb", 10, 5, 2, 5, ["n1", "n2", "n3", "n4"])
	var f := MERGE.fuse(a, b)
	eq(f.moves.size(), MERGE.MAX_MOVES, "a big union is capped at MAX_MOVES")


func test_generic_fused_identity() -> void:
	var a := _mk("aa", 10, 5, 2, 5, ["x"], 1)
	var b := _mk("bb", 12, 5, 2, 5, ["y"], 2)
	var f := MERGE.fuse(a, b)   # "aa|bb" is not a table pair -> generic
	check(f.source != null, "generic fused carries a synthetic source")
	check(String(f.source.id).is_empty(), "generic fused has no monster id (tint fallback)")
	check(f.display_name.begins_with("Fused"), "generic fused name is 'Fused <stronger>'")
	check(f.display_name.contains("Bb"), "name uses the stronger (higher-tier) parent")


func test_fusion_table_makes_a_specific_monster() -> void:
	var a := _mk("bat", 10, 5, 2, 5, ["x"])
	var b := _mk("slime", 10, 5, 2, 5, ["y"])
	var f := MERGE.fuse(a, b)   # bat|slime -> wraith
	eq(String(f.source.id), "wraith", "a table pair becomes the mapped monster")
	# Read the target's own display name rather than hardcoding it (it's editable via the dock).
	var wraith := load("res://assets/data/monsters/wraith.tres") as MonsterData
	eq(f.display_name, wraith.display_name, "the table result takes the target monster's name")
	check(not f.is_fused, "a named identity result is a real monster, not a dead end — it can be fused again (e.g. toward a chained recipe)")


func test_chained_identity_fusion() -> void:
	# chicken+rat -> goblin (identity, unfused), then that goblin + a skeleton -> gremlin_knob.
	# Chaining only works because the first result stayed eligible as a fusion parent.
	var chicken := _mk("chicken", 10, 5, 2, 5, ["x"])
	var rat := _mk("rat", 10, 5, 2, 5, ["y"])
	var goblin := MERGE.fuse(chicken, rat)
	eq(String(goblin.source.id), "goblin", "chicken+rat -> goblin")
	check(not goblin.is_fused, "the goblin result is still eligible to fuse again")
	var skeleton := _mk("skeleton", 10, 5, 2, 5, ["z"])
	var knob := MERGE.fuse(goblin, skeleton)
	eq(String(knob.source.id), "gremlin_knob", "the fused goblin can chain into goblin+skeleton -> gremlin_knob")


func test_two_griffins_forge_a_hydra() -> void:
	# griffin+griffin -> hydra is a same-id recipe pair — reachable in play because "griffin" has
	# two independent sources (the wild elite encounter, and the golem+spider fusion recipe).
	var a := _mk("griffin", 60, 15, 7, 9, ["x"])
	var b := _mk("griffin", 60, 15, 7, 9, ["y"])
	var f := MERGE.fuse(a, b)
	eq(String(f.source.id), "hydra", "griffin+griffin -> hydra")
	var hydra := load("res://assets/data/monsters/hydra.tres") as MonsterData
	eq(f.display_name, hydra.display_name, "the table result takes the hydra's own name")


func test_fusion_table_lookup_is_unordered() -> void:
	eq(FUSION.lookup("bat", "slime"), "wraith", "ordered lookup hits the recipe")
	eq(FUSION.lookup("slime", "bat"), "wraith", "reversed lookup gives the same result")
	eq(FUSION.lookup("chicken", "golem"), "", "an unlisted pair has no recipe")


func test_runstate_merge_shrinks_party_and_returns_fused() -> void:
	var rs = load("res://autoload/run_state.gd").new()
	rs.new_run(load("res://assets/data/monsters/slime.tres"))
	rs.add_monster(load("res://assets/data/monsters/bat.tres"))
	rs.add_monster(load("res://assets/data/monsters/chicken.tres"))
	var before: int = rs.party.size()
	var a = rs.party[0]
	var b = rs.party[1]
	var fused = rs.merge(a, b)
	eq(rs.party.size(), before - 1, "merge removes two and appends one (net -1, frees a slot)")
	check(not rs.party.has(a) and not rs.party.has(b), "both parents are removed")
	check(rs.party.has(fused), "the fused monster is now in the party")
	rs.free()
