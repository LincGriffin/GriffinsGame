extends Node2D
## The first dungeon room. Paints a TileMapLayer from an ASCII map, spawns the
## player on it, and turns "stepped onto a monster tile" into a (placeholder)
## battle trigger. The real battle scene comes later — for now we just print and
## emit a signal so the wiring seam is in place.

## Placeholder for the future battle hand-off. Carries the monster tile's cell.
signal battle_triggered(cell: Vector2i)

# Atlas coords into the TileSet (source id 0). Must match tools/gen_tileset.gd.
const SOURCE_ID := 0
const FLOOR := Vector2i(0, 0)
const WALL := Vector2i(1, 0)
const MONSTER := Vector2i(2, 0)

# Legend:  '#' wall   '.' floor   'M' monster tile   'P' player start (a floor)
# Edit freely — every row must be the same width.
const ROOM := [
	"####################",
	"#..................#",
	"#....##....M.......#",
	"#....##............#",
	"#........P.........#",
	"#..........####....#",
	"#..........#.......#",
	"#....M.....#.......#",
	"#..........#.......#",
	"#..................#",
	"#..................#",
	"####################",
]

@onready var tile_map_layer: TileMapLayer = $TileMapLayer
@onready var player: Player = $Player


func _ready() -> void:
	var start := _build_room()
	player.tile_map_layer = tile_map_layer
	player.snap_to_cell(start)
	player.moved.connect(_on_player_moved)


## Paint the ASCII map into the TileMapLayer. Returns the player's start cell.
func _build_room() -> Vector2i:
	var width := ROOM[0].length()
	var start := Vector2i(1, 1)
	for y in ROOM.size():
		var row: String = ROOM[y]
		assert(row.length() == width, "ROOM row %d has wrong width" % y)
		for x in row.length():
			var cell := Vector2i(x, y)
			match row[x]:
				"#":
					_paint(cell, WALL)
				"M":
					_paint(cell, MONSTER)
				"P":
					_paint(cell, FLOOR)
					start = cell
				_:
					_paint(cell, FLOOR)
	return start


func _paint(cell: Vector2i, atlas: Vector2i) -> void:
	tile_map_layer.set_cell(cell, SOURCE_ID, atlas)


## Fires each time the player finishes a step. If they landed on a monster tile,
## kick off the (placeholder) encounter.
func _on_player_moved(cell: Vector2i) -> void:
	var td := tile_map_layer.get_cell_tile_data(cell)
	if td != null and td.get_custom_data("monster"):
		print("Encounter at ", cell)
		battle_triggered.emit(cell)
		# Later, this is where we'd pause the overworld and load the battle scene.
		# On victory, clear the monster so it doesn't retrigger:
		#   tile_map_layer.set_cell(cell, SOURCE_ID, FLOOR)
