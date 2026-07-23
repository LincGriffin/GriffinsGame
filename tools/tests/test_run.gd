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
