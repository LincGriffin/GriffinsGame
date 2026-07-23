extends SceneTree
## One-off Magna-Tiles art generator.
## Run headless:  Godot_console.exe --headless --path <project> --script res://tools/gen_art.gd
## Produces assets/tilesets/dungeon_tiles.png (576x64, 9 tiles) and assets/sprites/player.png (64x64).
##
## Art direction (docs/DESIGN.md — "Magna-Tiles, whole game"): a real Magna-Tile is a
## *stained-glass panel in a beveled plastic frame*. Every tile is drawn that way:
##   - a dark outer rim, then a BEVELED FRAME (top/left catch the light, bottom/right fall
##     into shadow) — the raised plastic edge of the toy,
##   - a bright inner lip where the frame meets the glass,
##   - a TRANSLUCENT BACKLIT PANEL: a diagonal light falloff plus a soft centre glow, so the
##     tile reads as coloured plastic with a light behind it,
##   - a soft specular sheen streak across the upper-left.
## Special tiles add a faceted gem marker (also beveled, with its own highlight).
##
## Tiles are 64px so the bevel/gradient have room to read; the player Camera2D drops to
## zoom 1 to keep the on-screen scale identical to the old 32px art.

const TILE := 64
const HALF := 31.5   # tile centre in pixel space (0..63)

# Tile atlas layout (all one row). 0/1 are floor/wall; 2..8 are floor + a gem marker for
# each walkable node type. gen_tileset.gd mirrors these indices.
const TILE_COUNT := 9


func _init() -> void:
	_make_tileset()
	_make_player()
	print("gen_art: done")
	quit()


func _make_tileset() -> void:
	var img := Image.create(TILE * TILE_COUNT, TILE, false, Image.FORMAT_RGBA8)

	# Magna-Tiles primaries: floor = green glass, wall = a denser blue panel in a heavier
	# frame so it reads as solid structure you can't walk through.
	var floor_cfg := {
		"frame": 6,
		"light": Color8(196, 244, 212), "deep": Color8(46, 150, 92),
		"f_hi": Color8(96, 186, 128), "f_mid": Color8(38, 120, 74),
		"f_lo": Color8(22, 80, 50), "rim": Color8(16, 58, 36),
	}
	var wall_cfg := {
		"frame": 9,
		"light": Color8(186, 216, 255), "deep": Color8(46, 106, 206),
		"f_hi": Color8(96, 150, 232), "f_mid": Color8(30, 74, 160),
		"f_lo": Color8(18, 46, 110), "rim": Color8(12, 32, 80),
	}

	# Walkable node-marker gems: {index, radius, hi(centre), mid(body), lo(rim)}. Colours
	# track map_view.gd's TYPE_COLOR so the dungeon reads like the old node-map.
	var markers := [
		{"i": 2, "r": 20.0, "hi": Color8(255, 190, 184), "mid": Color8(224, 66, 66),  "lo": Color8(140, 26, 26)},   # battle  red
		{"i": 3, "r": 25.0, "hi": Color8(255, 247, 200), "mid": Color8(240, 202, 60), "lo": Color8(150, 110, 18)},  # boss    gold
		{"i": 4, "r": 21.0, "hi": Color8(206, 248, 212), "mid": Color8(70, 190, 110), "lo": Color8(26, 104, 58)},   # heal    green
		{"i": 5, "r": 21.0, "hi": Color8(255, 246, 190), "mid": Color8(238, 206, 70), "lo": Color8(146, 114, 18)},  # powerup yellow
		{"i": 6, "r": 21.0, "hi": Color8(202, 222, 255), "mid": Color8(78, 132, 236), "lo": Color8(26, 64, 148)},   # warp    blue
		{"i": 7, "r": 23.0, "hi": Color8(238, 204, 248), "mid": Color8(178, 70, 200), "lo": Color8(96, 28, 118)},   # elite   purple
		{"i": 8, "r": 21.0, "hi": Color8(255, 224, 186), "mid": Color8(240, 150, 50), "lo": Color8(146, 76, 18)},   # room    orange
	]

	for ty in range(TILE):
		for tx in range(TILE):
			var floor_px := _panel_pixel(tx, ty, floor_cfg)
			img.set_pixel(tx, ty, floor_px)                                  # 0 — floor
			img.set_pixel(TILE + tx, ty, _panel_pixel(tx, ty, wall_cfg))     # 1 — wall
			for m in markers:                                                # 2..8 — markers
				img.set_pixel(TILE * int(m["i"]) + tx, ty,
					_gem_pixel(tx, ty, floor_px, m["r"], m["hi"], m["mid"], m["lo"]))

	var err := img.save_png("res://assets/tilesets/dungeon_tiles.png")
	assert(err == OK, "failed to save dungeon_tiles.png")


## One pixel of a Magna-Tiles panel: dark rim → beveled frame → inner lip → backlit glass.
func _panel_pixel(tx: int, ty: int, cfg: Dictionary) -> Color:
	var x := float(tx)
	var y := float(ty)
	var d_top := y
	var d_left := x
	var d_right := float(TILE - 1) - x
	var d_bottom := float(TILE - 1) - y
	var edge := minf(minf(d_top, d_bottom), minf(d_left, d_right))
	var frame_px := float(cfg["frame"])

	if edge < 1.0:
		return cfg["rim"]                       # dark outer rim

	if edge < frame_px:
		# Beveled plastic frame — the top/left faces catch the light, bottom/right shade.
		var lit: bool = minf(d_top, d_left) <= minf(d_bottom, d_right)
		var t := (edge - 1.0) / maxf(1.0, frame_px - 1.0)
		var face: Color = cfg["f_hi"] if lit else cfg["f_lo"]
		return face.lerp(cfg["f_mid"], t)

	if edge < frame_px + 1.5:
		return (cfg["light"] as Color).lerp(Color(1, 1, 1), 0.35)   # bright inner lip

	# Translucent backlit glass: diagonal falloff (light from the upper-left) ...
	var u := (x + y) / (2.0 * float(TILE - 1))
	var col: Color = (cfg["light"] as Color).lerp(cfg["deep"], clampf(u * 1.15, 0.0, 1.0))
	# ... plus a soft glow from the centre, as if lit from behind ...
	var r := Vector2(x - HALF, y - HALF).length() / HALF
	col = col.lerp(cfg["light"], clampf(0.35 * (1.0 - r), 0.0, 1.0))
	# ... and a specular sheen streak across the upper-left.
	var s := absf((x - y) + 18.0)
	if s < 7.0 and (x + y) < float(TILE):
		col = col.lerp(Color(1, 1, 1), 0.20 * (1.0 - s / 7.0))
	return col


## Overlay a faceted diamond gem on `base`, returning the resulting pixel.
func _gem_pixel(tx: int, ty: int, base: Color, radius: float,
		hi: Color, mid: Color, lo: Color) -> Color:
	var dx := absf(float(tx) - HALF)
	var dy := absf(float(ty) - HALF)
	var dist := dx + dy            # diamond (manhattan) distance
	if dist > radius:
		return base
	if dist > radius - 3.0:
		return lo                  # gem rim
	if dist > radius - 5.0:
		return mid.lerp(hi, 0.35)  # inner bevel lip
	var col := hi.lerp(mid, clampf(dist / maxf(1.0, radius - 5.0), 0.0, 1.0))
	# Specular dot toward the upper-left facet.
	var spec := Vector2(float(tx) - (HALF - radius * 0.34), float(ty) - (HALF - radius * 0.34))
	var sr := radius * 0.20
	if spec.length() < sr:
		col = col.lerp(Color(1, 1, 1), 0.55 * (1.0 - spec.length() / sr))
	return col


func _make_player() -> void:
	# The room avatar — a translucent cyan crystal that pops on the green glass floor.
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	var clear := Color8(0, 0, 0, 0)
	var hi := Color8(226, 252, 255)
	var mid := Color8(70, 204, 238)
	var lo := Color8(18, 112, 146)
	var eye := Color8(16, 42, 56)

	var radius := 26.0
	for y in range(TILE):
		for x in range(TILE):
			if absf(float(x) - HALF) + absf(float(y) - HALF) > radius:
				img.set_pixel(x, y, clear)
			else:
				img.set_pixel(x, y, _gem_pixel(x, y, clear, radius, hi, mid, lo))

	# Two eyes give the avatar a face.
	for e in [Vector2i(24, 29), Vector2i(38, 29)]:
		for oy in range(3):
			for ox in range(3):
				img.set_pixel(e.x + ox, e.y + oy, eye)

	var err := img.save_png("res://assets/sprites/player.png")
	assert(err == OK, "failed to save player.png")
