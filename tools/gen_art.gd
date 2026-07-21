extends SceneTree
## One-off placeholder-art generator.
## Run headless:  Godot_console.exe --headless --path <project> --script res://tools/gen_art.gd
## Produces assets/tilesets/dungeon_tiles.png (96x32) and assets/sprites/player.png (32x32).
## Programmer art — meant to be replaced with real sprites later.

const TILE := 32

func _init() -> void:
	_make_tileset()
	_make_player()
	print("gen_art: done")
	quit()


func _make_tileset() -> void:
	# 3 tiles in a horizontal strip: [0]=floor  [1]=wall  [2]=monster marker
	var img := Image.create(TILE * 3, TILE, false, Image.FORMAT_RGBA8)

	var floor_base := Color8(58, 63, 75)      # #3A3F4B
	var floor_edge := Color8(44, 49, 60)      # #2C313C  (grid line)
	var wall_base := Color8(86, 92, 102)      # #565C66
	var wall_hi := Color8(110, 117, 129)      # #6E7581  (top/left bevel)
	var wall_lo := Color8(58, 62, 69)         # #3A3E45  (bottom/right bevel)
	var monster := Color8(217, 83, 79)        # #D9534F

	for ty in range(TILE):
		for tx in range(TILE):
			var on_edge := tx == 0 or ty == 0 or tx == TILE - 1 or ty == TILE - 1

			# Tile 0 — floor
			img.set_pixel(tx, ty, floor_edge if on_edge else floor_base)

			# Tile 1 — wall (base + simple bevel)
			var wc := wall_base
			if tx == 0 or ty == 0:
				wc = wall_hi
			elif tx == TILE - 1 or ty == TILE - 1:
				wc = wall_lo
			img.set_pixel(TILE + tx, ty, wc)

			# Tile 2 — floor with a red monster marker (filled circle)
			var mc := floor_edge if on_edge else floor_base
			var dx := float(tx) - 15.5
			var dy := float(ty) - 15.5
			if dx * dx + dy * dy <= 9.0 * 9.0:
				mc = monster
			img.set_pixel(TILE * 2 + tx, ty, mc)

	var err := img.save_png("res://assets/tilesets/dungeon_tiles.png")
	assert(err == OK, "failed to save dungeon_tiles.png")


func _make_player() -> void:
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	var clear := Color8(0, 0, 0, 0)
	var body := Color8(56, 189, 248)          # #38BDF8  bright teal
	var outline := Color8(14, 116, 144)       # #0E7490  darker teal
	var eye := Color8(255, 255, 255)

	# Transparent background so the floor shows around the character.
	for y in range(TILE):
		for x in range(TILE):
			img.set_pixel(x, y, clear)

	# Body: inset rounded-ish square from (4,4) to (27,27).
	var lo := 4
	var hi := 27
	for y in range(lo, hi + 1):
		for x in range(lo, hi + 1):
			var edge := x == lo or y == lo or x == hi or y == hi
			img.set_pixel(x, y, outline if edge else body)

	# Two eyes.
	img.set_pixel(11, 13, eye)
	img.set_pixel(12, 13, eye)
	img.set_pixel(19, 13, eye)
	img.set_pixel(20, 13, eye)

	var err := img.save_png("res://assets/sprites/player.png")
	assert(err == OK, "failed to save player.png")
