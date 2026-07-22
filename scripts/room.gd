extends Node2D
## A small walkable tile room, opened by the node-map's treasure nodes. Reuses the
## grid-movement engine (player.gd): paint a compact room, drop the player at the
## entrance, and emit `finished` when they reach the goal tile (the gold chest). The
## Run controller frees the room and applies the reward when it finishes.

signal finished

const SOURCE_ID := 0
const FLOOR := Vector2i(0, 0)
const WALL := Vector2i(1, 0)
const CHEST := Vector2i(3, 0)   # reuse the gold "boss" tile art as a treasure chest

# Legend: '#' wall  '.' floor  'C' chest (the goal)  'P' player start
const ROOM := [
	"#############",
	"#...........#",
	"#..##...##..#",
	"#..##...##..#",
	"#.....C.....#",
	"#..##...##..#",
	"#..##...##..#",
	"#.....P.....#",
	"#############",
]

@onready var tile_map_layer: TileMapLayer = $TileMapLayer
@onready var player: Player = $Player

var _goal := Vector2i.ZERO
var _done := false


func _ready() -> void:
	var start := _build_room()
	player.tile_map_layer = tile_map_layer
	player.snap_to_cell(start)
	player.moved.connect(_on_player_moved)


func _build_room() -> Vector2i:
	var start := Vector2i(1, 1)
	for y in ROOM.size():
		var row: String = ROOM[y]
		for x in row.length():
			var cell := Vector2i(x, y)
			match row[x]:
				"#":
					_paint(cell, WALL)
				"C":
					_paint(cell, CHEST)
					_goal = cell
				"P":
					_paint(cell, FLOOR)
					start = cell
				_:
					_paint(cell, FLOOR)
	return start


func _paint(cell: Vector2i, atlas: Vector2i) -> void:
	tile_map_layer.set_cell(cell, SOURCE_ID, atlas)


func _on_player_moved(cell: Vector2i) -> void:
	if _done:
		return
	if cell == _goal:
		_done = true
		player.set_physics_process(false)
		finished.emit()
