extends SceneTree
## Generates PLACEHOLDER upgrade icons at assets/upgrade_icons/<type>.png — one per power-up
## upgrade type (hp / attack / defense / move). These are simple procedural glyphs on a backlit
## coloured panel, in the spirit of the Magna-Tiles look but deliberately rough: they're stand-ins
## the user can replace with real art by dropping a same-named PNG in (see scripts/data/upgrade_icons.gd).
##
##   Godot_console.exe --headless --path <project> --script res://tools/gen_upgrade_icons.gd

const OUT := "res://assets/upgrade_icons/"
const SIZE := 128

# type -> base colour (kept in sync with UpgradeIcons.COLORS, which is also the fallback swatch)
const TINTS := {
	"hp": Color(0.85, 0.22, 0.28),
	"attack": Color(0.92, 0.55, 0.18),
	"defense": Color(0.26, 0.5, 0.9),
	"move": Color(0.62, 0.36, 0.86),
}


func _init() -> void:
	var da := DirAccess.open("res://")
	da.make_dir_recursive("assets/upgrade_icons")
	for type in TINTS:
		var img := _panel(TINTS[type])
		_draw_glyph(img, type)
		var dest: String = OUT + type + ".png"
		var err := img.save_png(dest)
		print("  %-8s -> %s [%s]" % [type, dest, "ok" if err == OK else "ERR %d" % err])
	quit()


## A backlit plastic panel: dark rim, coloured frame, lighter inner glass.
func _panel(base: Color) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var rim := Color(0.05, 0.05, 0.07)
	var frame := base.darkened(0.25)
	var glass := base.lightened(0.18)
	for y in SIZE:
		for x in SIZE:
			var d: int = min(min(x, SIZE - 1 - x), min(y, SIZE - 1 - y))
			var c: Color
			if d < 4:
				c = rim
			elif d < 12:
				c = frame
			else:
				# subtle top-to-bottom sheen on the inner glass
				var t := float(y) / SIZE
				c = glass.lerp(base, t)
			img.set_pixel(x, y, c)
	return img


func _draw_glyph(img: Image, type: String) -> void:
	var white := Color(0.97, 0.97, 1.0)
	match type:
		"hp":       # a bold plus
			_fill_rect(img, 54, 30, 20, 68, white)
			_fill_rect(img, 30, 54, 68, 20, white)
		"attack":   # an upward blade / chevron (solid triangle)
			_fill_triangle(img, Vector2(64, 24), Vector2(30, 100), Vector2(98, 100), white)
		"defense":  # a shield: square top narrowing to a point
			for y in range(30, 104):
				var t := float(y - 30) / 74.0
				var half := int(lerp(34.0, 4.0, t * t))   # widest at top, tapering to a point
				_fill_rect(img, 64 - half, y, half * 2, 1, white)
		"move":     # a four-point diamond / spark
			for y in SIZE:
				for x in SIZE:
					if abs(x - 64) + abs(y - 64) < 40:
						img.set_pixel(x, y, white)


func _fill_rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and xx < SIZE and yy >= 0 and yy < SIZE:
				img.set_pixel(xx, yy, c)


func _fill_triangle(img: Image, a: Vector2, b: Vector2, cc: Vector2, col: Color) -> void:
	var minx := int(min(a.x, min(b.x, cc.x)))
	var maxx := int(max(a.x, max(b.x, cc.x)))
	var miny := int(min(a.y, min(b.y, cc.y)))
	var maxy := int(max(a.y, max(b.y, cc.y)))
	for y in range(miny, maxy + 1):
		for x in range(minx, maxx + 1):
			if _in_tri(Vector2(x, y), a, b, cc):
				img.set_pixel(x, y, col)


func _in_tri(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := _sign(p, a, b)
	var d2 := _sign(p, b, c)
	var d3 := _sign(p, c, a)
	var has_neg := d1 < 0 or d2 < 0 or d3 < 0
	var has_pos := d1 > 0 or d2 > 0 or d3 > 0
	return not (has_neg and has_pos)


func _sign(p: Vector2, a: Vector2, b: Vector2) -> float:
	return (p.x - b.x) * (a.y - b.y) - (a.x - b.x) * (p.y - b.y)
