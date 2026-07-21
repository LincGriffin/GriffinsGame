extends SceneTree
## One-off TileSet generator — builds a valid .tres via the engine API.
## Run headless:  Godot_console.exe --headless --path <project> --script res://tools/gen_tileset.gd
##
## Tiles (atlas coords in dungeon_tiles.png):
##   (0,0) floor    walkable=true,  monster=false
##   (1,0) wall     walkable=false, monster=false
##   (2,0) monster  walkable=true,  monster=true
## Source id is fixed to 0 so scripts can reference it by a stable constant.

const TILE := Vector2i(32, 32)
const SOURCE_ID := 0

func _init() -> void:
	var ts := TileSet.new()
	ts.tile_size = TILE

	# Custom data layers (order defines index used by scripts).
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "walkable")
	ts.set_custom_data_layer_type(0, TYPE_BOOL)
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(1, "monster")
	ts.set_custom_data_layer_type(1, TYPE_BOOL)
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(2, "boss")
	ts.set_custom_data_layer_type(2, TYPE_BOOL)

	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/tilesets/dungeon_tiles.png")
	src.texture_region_size = TILE
	src.create_tile(Vector2i(0, 0))
	src.create_tile(Vector2i(1, 0))
	src.create_tile(Vector2i(2, 0))
	src.create_tile(Vector2i(3, 0))

	ts.add_source(src, SOURCE_ID)

	#         coords              walkable  monster  boss
	_set_tile(src, Vector2i(0, 0), true,    false,  false)  # floor
	_set_tile(src, Vector2i(1, 0), false,   false,  false)  # wall
	_set_tile(src, Vector2i(2, 0), true,    true,   false)  # monster
	_set_tile(src, Vector2i(3, 0), true,    true,   true)   # boss (also a monster tile)

	var err := ResourceSaver.save(ts, "res://assets/tilesets/dungeon_tileset.tres")
	assert(err == OK, "failed to save dungeon_tileset.tres")
	print("gen_tileset: done")
	quit()


func _set_tile(src: TileSetAtlasSource, coords: Vector2i, walkable: bool, monster: bool, boss: bool) -> void:
	var td := src.get_tile_data(coords, 0)
	td.set_custom_data("walkable", walkable)
	td.set_custom_data("monster", monster)
	td.set_custom_data("boss", boss)
