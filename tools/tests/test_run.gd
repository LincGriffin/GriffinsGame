extends "res://tools/tests/_base.gd"
## run.gd's encounter pre-roll: battle/elite/boss nodes get their monster assigned at
## map-generation time (not on room-entry), so dungeon_view.gd can show a monster-specific
## map sprite on the marker and re-entering a fled fight shows the same monster. Exercised
## directly on a detached Run node — no live scene tree / RunState autoload needed, since
## _assign_encounters only touches _map and the wild/elite pools.

const MAP_GENERATOR := preload("res://scripts/map/map_generator.gd")


func _new_run() -> Node:
	var run: Node = load("res://scripts/run.gd").new()
	run._rng.seed = 7
	run._build_wild_index()
	run._map = MAP_GENERATOR.new().generate(run._rng)
	return run


func test_encounter_nodes_get_a_pre_rolled_enemy() -> void:
	var run := _new_run()
	run._assign_encounters()
	for n in run._map["nodes"]:
		if n["type"] in ["battle", "elite", "boss"]:
			check(n.get("enemy") is MonsterData, "%s node %d gets a pre-rolled enemy" % [n["type"], n["id"]])
		else:
			check(not n.has("enemy"), "%s node %d has no enemy" % [n["type"], n["id"]])
	run.free()


func test_boss_node_enemy_is_the_hydra() -> void:
	var run := _new_run()
	run._assign_encounters()
	for n in run._map["nodes"]:
		if n["type"] == "boss":
			check(n["enemy"].is_boss, "the boss node's enemy is flagged as the boss")
	run.free()


## _build_run_record() only — never call _win()/_game_over() from a test, since both write to
## the REAL user://run_history.json via RunHistory.record() (scripts/data/run_history.gd).
func test_build_run_record_shape() -> void:
	var run := _new_run()
	var rs = load("res://autoload/run_state.gd").new()
	rs.new_run(load("res://assets/data/monsters/slime.tres"))
	run._gs = rs
	run._starter_id = "slime"
	run._nodes_resolved = 4
	run._battles_fought = 2
	run._died_to = "Goblin"
	run._died_at_row = 3
	run._recruited = ["bat"]

	var record: Dictionary = run._build_run_record("lost")
	eq(record["starter_id"], "slime", "starter_id carries through")
	eq(record["outcome"], "lost", "outcome carries through")
	eq(record["nodes_resolved"], 4, "nodes_resolved carries through")
	eq(record["battles_fought"], 2, "battles_fought carries through")
	eq(record["died_to"], "Goblin", "died_to carries through")
	eq(record["died_at_row"], 3, "died_at_row carries through")
	eq(record["recruited"], ["bat"], "recruited carries through")
	eq(record["final_party"].size(), 1, "final_party has one entry (the starter)")
	eq(record["final_party"][0]["id"], "slime", "final_party entries include the monster id")
	run.free()
	rs.free()
