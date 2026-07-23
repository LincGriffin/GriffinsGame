extends "res://tools/tests/_base.gd"
## The walkable dungeon (DungeonView): rooms + corridors form one connected, backtrackable
## space; stepping into an uncleared room triggers it; cleared rooms are walk-through and
## silent. Uses a live instance and drives the player like test_room / test_overworld.

var _view
var _map


func before_each() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4321
	_map = MapGenerator.new().generate(rng)
	_view = load("res://scripts/map/dungeon_view.gd").new()
	runner.root.add_child(_view)
	_view.setup(_map)
	await idle()
	await idle()


func after_each() -> void:
	_view.queue_free()
	await idle()


## The whole dungeon is connected: every room center is walkable AND reachable on foot from
## the spawn — this is what lets the player backtrack and eventually reach every node.
func test_every_room_reachable_and_walkable() -> void:
	var player = _view.player
	var seen := _flood(player, player.grid_cell)
	var ok := true
	for node in _map["nodes"]:
		var center: Vector2i = _view.room_center(int(node["id"]))
		if not player._is_walkable(center) or not seen.has(center):
			ok = false
	check(ok, "every room center is walkable and reachable from spawn")


func test_walking_into_a_room_triggers_it() -> void:
	var player = _view.player
	var goal: Vector2i = _view.room_center(int(_map["start_row_nodes"][0]))
	var dirs := _path_dirs(player, player.grid_cell, goal)
	check(not dirs.is_empty(), "found a walkable path from spawn into a start room")
	var fired := {"id": -99}
	_view.room_entered.connect(func(id): if fired.id == -99: fired.id = id)
	for d in dirs:
		await player._try_step(d)
		if fired.id != -99:
			break
	check(fired.id != -99, "walking into an uncleared room emits room_entered")


func test_cleared_room_is_walkthrough_and_silent() -> void:
	var player = _view.player
	var id: int = int(_map["nodes"][0]["id"])
	_view.clear_room(id)
	check(_view.is_cleared(id), "clear_room marks the node cleared")
	check(player._is_walkable(_view.room_center(id)), "a cleared room's center is walkable floor")
	var fired := {"hit": false}
	_view.room_entered.connect(func(_id): fired.hit = true)
	_view._on_player_moved(_view.room_center(id))
	check(not fired.hit, "a cleared room does not retrigger")


func test_warp_relocates_the_player() -> void:
	var player = _view.player
	var id: int = int(_map["boss"])
	_view.warp_to(id)
	eq(player.grid_cell, _view.room_center(id) + Vector2i(0, 1),
		"warp drops the player just below the target room's marker")


# --- helpers ---

## Flood-fill the set of cells reachable on foot (4-connected) from `start`.
func _flood(player, start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var frontier: Array = [start]
	while not frontier.is_empty():
		var c: Vector2i = frontier.pop_back()
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if not seen.has(n) and player._is_walkable(n):
				seen[n] = true
				frontier.append(n)
	return seen


## Shortest-path directions from `start` to `goal` over walkable cells ([] if unreachable).
func _path_dirs(player, start: Vector2i, goal: Vector2i) -> Array:
	var came := {start: start}
	var frontier: Array = [start]
	var found := false
	while not frontier.is_empty():
		var c: Vector2i = frontier.pop_front()
		if c == goal:
			found = true
			break
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if not came.has(n) and player._is_walkable(n):
				came[n] = c
				frontier.append(n)
	if not found:
		return []
	var cells: Array = [goal]
	var cur: Vector2i = goal
	while cur != start:
		cur = came[cur]
		cells.append(cur)
	cells.reverse()
	var dirs: Array = []
	for i in range(1, cells.size()):
		dirs.append(cells[i] - cells[i - 1])
	return dirs
