extends SceneTree
## One-off Magna-Tiles art generator.
## Run headless:  Godot_console.exe --headless --path <project> --script res://tools/gen_art.gd
## Produces assets/tilesets/dungeon_tiles.png (128x32, 4 tiles) and assets/sprites/player.png (32x32).
##
## Art direction (docs/DESIGN.md — "Magna-Tiles, whole game"): every tile reads like a
## backlit translucent plastic square — a light center that saturates toward the edge
## (soft inner glow), wrapped in a defined same-hue border. Special tiles carry a bright
## translucent gem (diamond) in a primary color. The player is a translucent gem avatar.

const TILE := 32
const HALF := 15.5   # tile center in pixel space (0..31)

func _init() -> void:
	_make_tileset()
	_make_player()
	print("gen_art: done")
	quit()


func _make_tileset() -> void:
	# 4 tiles in a horizontal strip: [0]=floor [1]=wall [2]=monster [3]=boss marker.
	var img := Image.create(TILE * 4, TILE, false, Image.FORMAT_RGBA8)

	# Magna-Tiles primaries: floor = green, wall = blue. Center is a light "backlit" tint,
	# edge is the saturated hue, and a darker same-hue border frames each tile.
	var floor_edge := Color8(52, 150, 96)     # saturated green
	var floor_center := Color8(150, 226, 176)  # light backlit green
	var floor_border := Color8(30, 96, 60)

	var wall_edge := Color8(56, 118, 214)     # saturated blue
	var wall_center := Color8(150, 194, 250)   # light backlit blue
	var wall_border := Color8(26, 62, 140)

	for ty in range(TILE):
		for tx in range(TILE):
			# Tile 0 — floor
			img.set_pixel(tx, ty, _plastic(tx, ty, floor_center, floor_edge, floor_border, 1))
			# Tile 1 — wall (deeper border reads as solid structure)
			img.set_pixel(TILE + tx, ty, _plastic(tx, ty, wall_center, wall_edge, wall_border, 2))
			# Tile 2 — floor + red monster gem
			var mc := _plastic(tx, ty, floor_center, floor_edge, floor_border, 1)
			img.set_pixel(TILE * 2 + tx, ty, _gem(tx, ty, mc, 9.5,
				Color8(255, 176, 170), Color8(224, 66, 66), Color8(150, 28, 28)))
			# Tile 3 — floor + larger yellow boss gem
			var bc := _plastic(tx, ty, floor_center, floor_edge, floor_border, 1)
			img.set_pixel(TILE * 3 + tx, ty, _gem(tx, ty, bc, 12.0,
				Color8(255, 246, 196), Color8(240, 202, 60), Color8(160, 120, 20)))

	var err := img.save_png("res://assets/tilesets/dungeon_tiles.png")
	assert(err == OK, "failed to save dungeon_tiles.png")


## A backlit plastic square: light `center` glows out to the saturated `edge`, with a
## `border`-thick same-hue frame. Uses a square (chebyshev) falloff so the glow fills the
## square evenly rather than darkening the corners.
func _plastic(tx: int, ty: int, center: Color, edge: Color, border: Color, border_px: int) -> Color:
	if tx < border_px or ty < border_px or tx >= TILE - border_px or ty >= TILE - border_px:
		return border
	var d := maxf(absf(float(tx) - HALF), absf(float(ty) - HALF)) / HALF
	return center.lerp(edge, clampf(d, 0.0, 1.0))


## Paint a translucent-looking diamond gem centered on the tile over `base`, returning the
## resulting pixel color. Inside the diamond: light `hi` center glowing to saturated `mid`,
## ringed by `lo`. Outside: `base` unchanged.
func _gem(tx: int, ty: int, base: Color, radius: float, hi: Color, mid: Color, lo: Color) -> Color:
	var dx := absf(float(tx) - HALF)
	var dy := absf(float(ty) - HALF)
	var dist := dx + dy   # diamond (manhattan) distance
	if dist > radius:
		return base
	if dist > radius - 2.0:
		return lo          # gem border ring
	return hi.lerp(mid, clampf(dist / (radius - 2.0), 0.0, 1.0))


func _make_player() -> void:
	# The room avatar — a bright translucent cyan gem that pops on the green floor.
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	var clear := Color8(0, 0, 0, 0)
	var hi := Color8(220, 250, 255)      # backlit center
	var mid := Color8(72, 204, 236)      # saturated cyan
	var lo := Color8(20, 118, 150)       # border ring
	var eye := Color8(18, 40, 52)

	var radius := 13.0
	for y in range(TILE):
		for x in range(TILE):
			var dist := absf(float(x) - HALF) + absf(float(y) - HALF)
			if dist > radius:
				img.set_pixel(x, y, clear)
			elif dist > radius - 2.0:
				img.set_pixel(x, y, lo)
			else:
				img.set_pixel(x, y, hi.lerp(mid, clampf(dist / (radius - 2.0), 0.0, 1.0)))

	# Two eyes give the avatar a facing/character read.
	for e in [Vector2i(12, 14), Vector2i(19, 14)]:
		img.set_pixel(e.x, e.y, eye)
		img.set_pixel(e.x + 1, e.y, eye)

	var err := img.save_png("res://assets/sprites/player.png")
	assert(err == OK, "failed to save player.png")
