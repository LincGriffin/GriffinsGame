extends "res://tools/tests/_base.gd"
## Map encounters must be UNIQUE — no monster appears twice on a map. The wild roster is small
## (tier 0 especially), so the pickers widen and only repeat once the roster is genuinely spent;
## these tests pin both the uniqueness and that fallback. Run on a detached Run (same approach as
## test_run.gd) — _assign_encounters only touches _map and the pools.

const MAP_GENERATOR := preload("res://scripts/map/map_generator.gd")


func _new_run(seed_value := 7) -> Node:
	var run: Node = load("res://scripts/run.gd").new()
	run._rng.seed = seed_value
	run._build_wild_index()
	run._map = MAP_GENERATOR.new().generate(run._rng)
	return run


func _ids_of(run: Node, type: String) -> Array:
	var out: Array = []
	for n in run._map["nodes"]:
		if n["type"] == type and n.get("enemy") != null:
			out.append(String(n["enemy"].id))
	return out


func _unique(ids: Array) -> int:
	var seen := {}
	for i in ids:
		seen[i] = true
	return seen.size()


func test_wild_encounters_are_unique_across_a_map() -> void:
	# Over several seeds so we're not just lucky with one layout.
	for s in [1, 7, 42, 99]:
		var run := _new_run(s)
		run._assign_encounters()
		var ids := _ids_of(run, "battle")
		var cap: int = run._wild_enemies.size()
		# Every battle is a different monster, until the roster is genuinely exhausted.
		eq(_unique(ids), mini(ids.size(), cap),
			"seed %d: %d battles use %d distinct monsters (roster of %d)"
				% [s, ids.size(), mini(ids.size(), cap), cap])
		run.free()


func test_elite_encounters_are_unique_across_a_map() -> void:
	for s in [1, 7, 42, 99]:
		var run := _new_run(s)
		run._assign_encounters()
		var ids := _ids_of(run, "elite")
		var cap: int = run._elite_enemies.size()
		eq(_unique(ids), mini(ids.size(), cap),
			"seed %d: elites are distinct until the elite pool is spent" % s)
		run.free()


func test_pick_wild_skips_already_used_monsters() -> void:
	var run := _new_run()
	var used := {}
	var picks: Array = []
	# Draw as many as the roster holds — each must be new.
	for i in run._wild_enemies.size():
		picks.append(String(run._pick_wild(0, used).id))
	eq(_unique(picks), run._wild_enemies.size(),
		"drawing roster-size times yields every monster exactly once")
	run.free()


func test_pick_wild_repeats_only_after_the_roster_is_exhausted() -> void:
	var run := _new_run()
	var used := {}
	for i in run._wild_enemies.size():
		run._pick_wild(0, used)
	# Roster spent — the next pick must still return a valid monster rather than null/erroring.
	var extra = run._pick_wild(0, used)
	check(extra != null, "an over-full map still gets an enemy (a repeat) instead of nothing")
	run.free()
