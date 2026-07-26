extends SceneTree
## Placeholder monster art generator — draws a portrait (assets/portraits/<id>.png) and a map
## sprite (assets/map_sprites/<id>.png) for monsters that don't have hand-made art yet.
##
## The portraits are **stylized procedural creatures** (a mushroom, a wisp, a horned imp, a
## reptilian kobold…) on a framed, vignetted panel — a clear step up from a plain gem, but still
## NOT the painterly style of the hand-made 12; they're placeholders until real art is dropped in
## (Portraits/MapSprites just load() by convention, so replacing one is a one-file drop + --import).
## The map sprite stays a simple faceted gem crystal (a small dungeon token, drawn deterministically).
##
## Edit MONSTERS below (id + tint, matching gen_content.gd's ROSTER) and run:
##   Godot_console.exe --headless --path <project> --script res://tools/gen_placeholder_monster_art.gd

const PORTRAIT_DIR := "res://assets/portraits/"
const MAP_SPRITE_DIR := "res://assets/map_sprites/"
const SIZE := 256

# id -> tint (keep in sync with the corresponding gen_content.gd ROSTER rows). The `shape` picks
# which creature is drawn for the portrait.
const MONSTERS := {
	"kobold":  {"tint": Color(0.78, 0.50, 0.28), "shape": "kobold"},
	"myconid": {"tint": Color(0.42, 0.62, 0.50), "shape": "myconid"},
	"wisp":    {"tint": Color(0.60, 0.85, 0.90), "shape": "wisp"},
	"imp":     {"tint": Color(0.85, 0.35, 0.30), "shape": "imp"},
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PORTRAIT_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MAP_SPRITE_DIR))
	for id in MONSTERS:
		var cfg: Dictionary = MONSTERS[id]
		_save(_make_portrait(cfg["tint"], cfg["shape"]), PORTRAIT_DIR + id + ".png")
		_save(_make_map_sprite(cfg["tint"]), MAP_SPRITE_DIR + id + ".png")
	print("gen_placeholder_monster_art: done (%d monsters)" % MONSTERS.size())
	quit()


func _save(img: Image, path: String) -> void:
	var err := img.save_png(ProjectSettings.globalize_path(path))
	assert(err == OK, "failed to save " + path)
	print("wrote ", path)


# ── Portrait: a framed, dark-vignette panel with a stylized creature centered on it ──────────────

func _make_portrait(tint: Color, shape: String) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_paint_backdrop(img, tint)
	match shape:
		"myconid": _draw_myconid(img, tint)
		"wisp":    _draw_wisp(img, tint)
		"imp":     _draw_imp(img, tint)
		"kobold":  _draw_kobold(img, tint)
	return img


## Beveled plastic frame (Magna-Tiles look) around a dark, tinted, vignetted inner panel so the
## creature pops — echoing the murky backgrounds of the hand-made portraits.
func _paint_backdrop(img: Image, tint: Color) -> void:
	var frame := 20.0
	var rim := tint.lerp(Color.BLACK, 0.72)
	var f_hi := tint.lerp(Color.WHITE, 0.35)
	var f_lo := tint.lerp(Color.BLACK, 0.35)
	var inner_deep := tint.lerp(Color(0.05, 0.05, 0.07), 0.78)   # near-black, faintly tinted
	var inner_glow := tint.lerp(Color.BLACK, 0.45)
	var half := SIZE * 0.5
	for y in SIZE:
		for x in SIZE:
			var edge := float(min(min(x, SIZE - 1 - x), min(y, SIZE - 1 - y)))
			var col: Color
			if edge < 3.0:
				col = rim
			elif edge < frame:
				var lit: bool = min(y, x) <= min(SIZE - 1 - y, SIZE - 1 - x)
				col = (f_hi if lit else f_lo).lerp(tint, (edge - 3.0) / (frame - 3.0))
			else:
				# radial vignette: brighter-tinted toward centre, near-black at the edges
				var r := Vector2(x - half, y - half).length() / (half - frame)
				col = inner_glow.lerp(inner_deep, clampf(r, 0.0, 1.0))
			img.set_pixel(x, y, col)


# ── Creatures ────────────────────────────────────────────────────────────────────────────────
# All centred around x=128. Drawn from simple primitives (discs / ellipses / triangles) with a
# base + a lighter up-left highlight + a darker rim, then features (eyes/horns/spots).

func _draw_myconid(img: Image, tint: Color) -> void:
	var stalk := Color(0.90, 0.87, 0.76)
	var stalk_lo := stalk.lerp(Color.BLACK, 0.28)
	# stalk (body)
	_ellipse(img, 128, 172, 30, 52, stalk_lo)
	_ellipse(img, 124, 168, 24, 46, stalk)
	# eyes on the stalk
	_disc(img, 114, 168, 7, Color(0.12, 0.12, 0.14))
	_disc(img, 142, 168, 7, Color(0.12, 0.12, 0.14))
	_disc(img, 112, 165, 2, Color.WHITE)
	_disc(img, 140, 165, 2, Color.WHITE)
	# cap
	var cap := tint
	var cap_hi := tint.lerp(Color.WHITE, 0.30)
	var cap_lo := tint.lerp(Color.BLACK, 0.40)
	_dome(img, 128, 118, 86, 60, cap_lo)
	_dome(img, 128, 118, 80, 55, cap)
	_dome(img, 118, 110, 54, 34, cap_hi)
	# spots
	for p in [Vector2(96, 104), Vector2(150, 96), Vector2(132, 120), Vector2(168, 118)]:
		_disc(img, int(p.x), int(p.y), 9, cap_hi.lerp(Color.WHITE, 0.4))


func _draw_wisp(img: Image, tint: Color) -> void:
	var half := SIZE * 0.5
	# soft aura
	for y in range(40, 210):
		for x in range(40, 216):
			var d := Vector2(x - 128, y - 122).length()
			if d < 92:
				_px(img, x, y, tint.lerp(Color.WHITE, 0.25), 0.5 * (1.0 - d / 92.0))
	# glowing core
	_disc(img, 128, 122, 46, tint.lerp(Color.WHITE, 0.35))
	_disc(img, 128, 122, 32, tint.lerp(Color.WHITE, 0.65))
	_disc(img, 122, 116, 18, Color(1, 1, 1, 1))
	# trailing wisp tail (a few shrinking discs downward)
	for i in range(1, 6):
		_disc(img, 128 + (i % 2) * 8 - 4, 168 + i * 12, 14 - i * 2,
			tint.lerp(Color.WHITE, 0.4 - i * 0.05), 0.7)
	# eyes
	_disc(img, 116, 120, 8, tint.lerp(Color.BLACK, 0.55))
	_disc(img, 140, 120, 8, tint.lerp(Color.BLACK, 0.55))
	# sparkles
	for p in [Vector2(74, 78), Vector2(186, 92), Vector2(196, 150), Vector2(66, 150)]:
		_disc(img, int(p.x), int(p.y), 3, Color(1, 1, 1))


func _draw_imp(img: Image, tint: Color) -> void:
	var base := tint
	var hi := tint.lerp(Color.WHITE, 0.28)
	var lo := tint.lerp(Color.BLACK, 0.42)
	# horns
	_tri(img, Vector2(104, 78), Vector2(88, 26), Vector2(120, 74), lo)
	_tri(img, Vector2(152, 78), Vector2(168, 26), Vector2(136, 74), lo)
	# ears (pointed, out to the sides)
	_tri(img, Vector2(74, 118), Vector2(40, 96), Vector2(84, 150), base)
	_tri(img, Vector2(182, 118), Vector2(216, 96), Vector2(172, 150), base)
	# head
	_ellipse(img, 128, 132, 64, 60, lo)
	_ellipse(img, 128, 132, 58, 54, base)
	_ellipse(img, 116, 120, 34, 28, hi)
	# angry brow
	_tri(img, Vector2(96, 118), Vector2(126, 128), Vector2(96, 130), lo)
	_tri(img, Vector2(160, 118), Vector2(130, 128), Vector2(160, 130), lo)
	# glowing eyes
	_disc(img, 110, 132, 12, Color(1.0, 0.86, 0.25))
	_disc(img, 146, 132, 12, Color(1.0, 0.86, 0.25))
	_disc(img, 110, 132, 5, Color(0.15, 0.06, 0.0))
	_disc(img, 146, 132, 5, Color(0.15, 0.06, 0.0))
	# fanged grin
	_tri(img, Vector2(108, 160), Vector2(148, 160), Vector2(128, 178), lo)
	_tri(img, Vector2(114, 160), Vector2(120, 160), Vector2(117, 172), Color.WHITE)
	_tri(img, Vector2(136, 160), Vector2(142, 160), Vector2(139, 172), Color.WHITE)


func _draw_kobold(img: Image, tint: Color) -> void:
	var base := tint
	var hi := tint.lerp(Color.WHITE, 0.28)
	var lo := tint.lerp(Color.BLACK, 0.42)
	var belly := tint.lerp(Color(0.95, 0.9, 0.7), 0.5)
	# back-swept head spikes
	_tri(img, Vector2(110, 78), Vector2(150, 40), Vector2(132, 82), lo)
	_tri(img, Vector2(134, 80), Vector2(176, 52), Vector2(150, 90), lo)
	# ears
	_tri(img, Vector2(84, 110), Vector2(58, 84), Vector2(96, 128), base)
	_tri(img, Vector2(172, 110), Vector2(198, 84), Vector2(160, 128), base)
	# head
	_ellipse(img, 128, 116, 56, 50, lo)
	_ellipse(img, 128, 116, 50, 44, base)
	_ellipse(img, 116, 106, 30, 24, hi)
	# snout
	_ellipse(img, 128, 158, 40, 30, lo)
	_ellipse(img, 128, 156, 34, 25, base)
	_ellipse(img, 128, 166, 26, 14, belly)
	# nostrils
	_disc(img, 118, 160, 3, Color(0.1, 0.06, 0.03))
	_disc(img, 138, 160, 3, Color(0.1, 0.06, 0.03))
	# reptilian eyes (yellow with a vertical slit)
	_disc(img, 110, 118, 12, Color(0.95, 0.82, 0.2))
	_disc(img, 146, 118, 12, Color(0.95, 0.82, 0.2))
	_rect(img, 109, 110, 2, 16, Color(0.1, 0.08, 0.0))
	_rect(img, 145, 110, 2, 16, Color(0.1, 0.08, 0.0))
	# brow ridges
	_tri(img, Vector2(96, 106), Vector2(124, 114), Vector2(96, 116), lo)
	_tri(img, Vector2(160, 106), Vector2(132, 114), Vector2(160, 116), lo)


# ── Map sprite: a faceted gem crystal on transparent (a small dungeon token) ─────────────────────

func _make_map_sprite(tint: Color) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var g_hi := tint.lerp(Color.WHITE, 0.55)
	var g_mid := tint.lerp(Color.WHITE, 0.05)
	var g_lo := tint.lerp(Color.BLACK, 0.35)
	var half := SIZE * 0.5
	var radius := SIZE * 0.40
	for y in SIZE:
		for x in SIZE:
			var dist := absf(x - half) + absf(y - half)
			if dist <= radius:
				var col: Color
				if dist > radius - 10.0:
					col = g_lo
				elif dist > radius - 18.0:
					col = g_mid.lerp(g_hi, 0.35)
				else:
					col = g_hi.lerp(g_mid, clampf(dist / maxf(1.0, radius - 18.0), 0.0, 1.0))
					var spec := Vector2(float(x) - (half - radius * 0.34), float(y) - (half - radius * 0.34))
					var sr := radius * 0.20
					if spec.length() < sr:
						col = col.lerp(Color.WHITE, 0.55 * (1.0 - spec.length() / sr))
				img.set_pixel(x, y, col)
	return img


# ── Drawing primitives ───────────────────────────────────────────────────────────────────────

## Blend `color` onto pixel (x,y) with alpha `a` (bounds-checked).
func _px(img: Image, x: int, y: int, color: Color, a := 1.0) -> void:
	if x < 0 or y < 0 or x >= SIZE or y >= SIZE or a <= 0.0:
		return
	if a >= 1.0:
		img.set_pixel(x, y, color)
	else:
		img.set_pixel(x, y, img.get_pixel(x, y).lerp(color, a))


func _disc(img: Image, cx: int, cy: int, r: int, color: Color, a := 1.0) -> void:
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			var d := sqrt(float((x - cx) * (x - cx) + (y - cy) * (y - cy)))
			if d <= r:
				_px(img, x, y, color, a * clampf(r - d, 0.0, 1.0))


func _ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, color: Color, a := 1.0) -> void:
	for y in range(cy - ry, cy + ry + 1):
		for x in range(cx - rx, cx + rx + 1):
			var nx := float(x - cx) / float(rx)
			var ny := float(y - cy) / float(ry)
			var d := sqrt(nx * nx + ny * ny)
			if d <= 1.0:
				_px(img, x, y, color, a * clampf((1.0 - d) * min(rx, ry), 0.0, 1.0))


## Upper half of an ellipse (a mushroom-cap dome) — only pixels at or above the centre y.
func _dome(img: Image, cx: int, cy: int, rx: int, ry: int, color: Color, a := 1.0) -> void:
	for y in range(cy - ry, cy + 1):
		for x in range(cx - rx, cx + rx + 1):
			var nx := float(x - cx) / float(rx)
			var ny := float(y - cy) / float(ry)
			var d := sqrt(nx * nx + ny * ny)
			if d <= 1.0:
				_px(img, x, y, color, a * clampf((1.0 - d) * min(rx, ry), 0.0, 1.0))


func _rect(img: Image, x0: int, y0: int, w: int, h: int, color: Color) -> void:
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			_px(img, x, y, color)


func _tri(img: Image, p0: Vector2, p1: Vector2, p2: Vector2, color: Color, a := 1.0) -> void:
	var minx := int(floor(min(p0.x, min(p1.x, p2.x))))
	var maxx := int(ceil(max(p0.x, max(p1.x, p2.x))))
	var miny := int(floor(min(p0.y, min(p1.y, p2.y))))
	var maxy := int(ceil(max(p0.y, max(p1.y, p2.y))))
	for y in range(miny, maxy + 1):
		for x in range(minx, maxx + 1):
			if _in_tri(Vector2(x, y), p0, p1, p2):
				_px(img, x, y, color, a)


func _in_tri(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := _edge(p, a, b)
	var d2 := _edge(p, b, c)
	var d3 := _edge(p, c, a)
	var neg := d1 < 0.0 or d2 < 0.0 or d3 < 0.0
	var pos := d1 > 0.0 or d2 > 0.0 or d3 > 0.0
	return not (neg and pos)


func _edge(p: Vector2, a: Vector2, b: Vector2) -> float:
	return (p.x - b.x) * (a.y - b.y) - (a.x - b.x) * (p.y - b.y)
