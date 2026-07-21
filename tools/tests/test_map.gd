extends "res://tools/tests/_base.gd"
## Node-map generation: structural properties of the layered DAG (pure, no scene).

func _gen(seed_val: int = 12345) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	return MapGenerator.new().generate(rng)


## BFS over `to` edges from the start-row nodes; returns the set of reachable ids.
func _reachable(m: Dictionary) -> Dictionary:
	var nodes: Array = m["nodes"]
	var seen := {}
	var frontier: Array = m["start_row_nodes"].duplicate()
	for id in frontier:
		seen[id] = true
	while not frontier.is_empty():
		var id = frontier.pop_back()
		for t in nodes[id]["to"]:
			if not seen.has(t):
				seen[t] = true
				frontier.append(t)
	return seen


func test_has_start_and_boss() -> void:
	var m := _gen()
	check(not m["start_row_nodes"].is_empty(), "has at least one start node")
	var boss = m["nodes"][m["boss"]]
	eq(boss["type"], "boss", "boss node is typed boss")
	check(boss["to"].is_empty(), "boss is terminal (no outgoing edges)")


func test_every_node_reachable_from_start() -> void:
	var m := _gen()
	var seen := _reachable(m)
	eq(seen.size(), m["nodes"].size(), "BFS from the starts reaches every node")


func test_boss_reachable() -> void:
	var m := _gen()
	var seen := _reachable(m)
	check(seen.has(m["boss"]), "the boss is reachable from the start")


func test_non_boss_nodes_have_outgoing() -> void:
	var m := _gen()
	for n in m["nodes"]:
		if n["id"] == m["boss"]:
			continue
		check(not n["to"].is_empty(), "node %d has an outgoing edge" % n["id"])


func test_rows_span_start_to_boss() -> void:
	var m := _gen()
	var max_row := 0
	for n in m["nodes"]:
		max_row = maxi(max_row, n["row"])
	eq(m["nodes"][m["boss"]]["row"], max_row, "boss sits on the last row")
	eq(m["rows"], max_row + 1, "reported row count matches")


func test_deterministic_with_same_seed() -> void:
	var a := _gen(777)
	var b := _gen(777)
	eq(a["nodes"].size(), b["nodes"].size(), "same seed -> same node count")
	eq(a["boss"], b["boss"], "same seed -> same boss id")


func test_only_known_types() -> void:
	var allowed := ["battle", "heal", "powerup", "teleport", "boss"]
	for n in _gen()["nodes"]:
		check(allowed.has(n["type"]), "node type '%s' is known" % n["type"])
