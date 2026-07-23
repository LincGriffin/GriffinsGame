class_name DungeonView
extends Node2D
## Renders a run's branching map (from MapGenerator) as a WALKABLE dungeon: each node is a
## small room, each edge a short corridor. The whole thing is connected and open, so the
## player can walk (and backtrack) freely and eventually reach every node. Stepping into an
## uncleared room's interior triggers its node — emit `room_entered(id)`; the Run controller
## resolves it and calls `clear_room(id)`, after which the room is walk-through floor.
##
## Built in code (no .tscn). Owns the TileMapLayer and a Player instance (whose Camera2D
## follows). Reuses the grid-movement engine wholesale (scripts/player.gd).

signal room_entered(id: int)

const PLAYER_SCENE := preload("res://scenes/overworld/player.tscn")
const TILESET := preload("res://assets/tilesets/dungeon_tileset.tres")
const SOURCE_ID := 0

const FLOOR := Vector2i(0, 0)
const WALL := Vector2i(1, 0)
# Atlas coord of the marker gem for each node type (see gen_art.gd / gen_tileset.gd).
const MARKER := {
	"battle": Vector2i(2, 0), "boss": Vector2i(3, 0), "heal": Vector2i(4, 0),
	"powerup": Vector2i(5, 0), "teleport": Vector2i(6, 0), "elite": Vector2i(7, 0),
	"room": Vector2i(8, 0),
}

const ROOM := 5           # each room is 5x5: a 3x3 interior inside a wall ring
const GAP := 2            # corridor gap between rooms
const CELL := ROOM + GAP  # tile pitch per map row/col
const ENTRANCE := -1      # virtual node id: the spawn room below row 0

var tile_map_layer: TileMapLayer
var player: Player

var _map: Dictionary = {}
var _origin: Dictionary = {}       # id -> Vector2i room top-left (incl. ENTRANCE)
var _room_cells: Dictionary = {}   # interior Vector2i -> id (stepping it triggers the node)
var _cleared: Dictionary = {}      # id -> true


func setup(map: Dictionary) -> void:
	_map = map
	tile_map_layer = TileMapLayer.new()
	tile_map_layer.tile_set = TILESET
	add_child(tile_map_layer)

	var rows: int = map["rows"]
	var max_col := 0
	for n in map["nodes"]:
		max_col = maxi(max_col, int(n["col"]))
	_origin[ENTRANCE] = _cell_origin(-1, int(max_col / 2), rows)
	for n in map["nodes"]:
		_origin[int(n["id"])] = _cell_origin(int(n["row"]), int(n["col"]), rows)

	# Paint every room (walls + interior + marker) and register its interior trigger cells.
	_paint_room(ENTRANCE, null)
	for n in map["nodes"]:
		_paint_room(int(n["id"]), MARKER.get(n["type"], FLOOR))

	# Carve every corridor — all open, so the dungeon is one connected walkable space.
	for s in map["start_row_nodes"]:
		_carve_corridor(ENTRANCE, int(s))
	for n in map["nodes"]:
		for t in n["to"]:
			_carve_corridor(int(n["id"]), int(t))

	# Spawn the player in the entrance room; the Camera2D in player.tscn follows.
	player = PLAYER_SCENE.instantiate()
	player.name = "Player"
	add_child(player)
	player.tile_map_layer = tile_map_layer
	player.snap_to_cell(_center(ENTRANCE))
	player.moved.connect(_on_player_moved)


# Row 0 sits at the bottom, boss at the top; the entrance (row -1) is below row 0.
func _cell_origin(row: int, col: int, rows: int) -> Vector2i:
	return Vector2i(col * CELL, (rows - 1 - row) * CELL)


func _center(id: int) -> Vector2i:
	return _origin[id] + Vector2i(2, 2)


func _paint_room(id: int, marker) -> void:
	var o: Vector2i = _origin[id]
	for dy in range(ROOM):
		for dx in range(ROOM):
			var c := o + Vector2i(dx, dy)
			var border := dx == 0 or dy == 0 or dx == ROOM - 1 or dy == ROOM - 1
			_paint(c, WALL if border else FLOOR)
			if not border and id != ENTRANCE:
				_room_cells[c] = id   # stepping any interior cell triggers the node
	if marker != null and id != ENTRANCE:
		_paint(o + Vector2i(2, 2), marker)


# Carve a corridor from room a up to room b (b is one CELL above a). Route out of a's top
# doorway, across a clean gap band, and into b's bottom doorway — straight or a short L.
func _carve_corridor(a: int, b: int) -> void:
	var ao: Vector2i = _origin[a]
	var bo: Vector2i = _origin[b]
	var ax := ao.x + 2
	var bx := bo.x + 2
	var gap_y := ao.y - 2                        # a clean band just above room a
	_paint(Vector2i(ax, ao.y), FLOOR)              # doorway out of a (its top wall)
	_paint(Vector2i(ax, ao.y - 1), FLOOR)
	_paint(Vector2i(ax, gap_y), FLOOR)
	for x in range(mini(ax, bx), maxi(ax, bx) + 1):
		_paint(Vector2i(x, gap_y), FLOOR)
	_paint(Vector2i(bx, bo.y + ROOM - 1), FLOOR)   # doorway into b (its bottom wall)


func _paint(cell: Vector2i, atlas: Vector2i) -> void:
	tile_map_layer.set_cell(cell, SOURCE_ID, atlas)


func _on_player_moved(cell: Vector2i) -> void:
	if _room_cells.has(cell):
		var id: int = _room_cells[cell]
		if not _cleared.has(id):
			room_entered.emit(id)


# --- API for the Run controller ---

## Pause/resume keyboard movement (e.g. while a battle overlay is up).
func set_walking(enabled: bool) -> void:
	if player != null:
		player.set_physics_process(enabled)


## Mark a node resolved: drop its marker so it's walk-through and never retriggers.
func clear_room(id: int) -> void:
	_cleared[id] = true
	_paint(_center(id), FLOOR)


func is_cleared(id: int) -> bool:
	return _cleared.has(id)


## The tile a room's marker sits on (also the room's trigger center). Used by tests.
func room_center(id: int) -> Vector2i:
	return _center(id)


## Teleport: drop the player at the entrance of room `id` (an interior cell just below its
## marker) so they walk up into it. snap_to_cell is silent, so it doesn't self-trigger.
func warp_to(id: int) -> void:
	if player != null:
		player.snap_to_cell(_origin[id] + Vector2i(2, ROOM - 2))
