extends SceneTree
## Placeholder monster art generator — draws a portrait (assets/portraits/<id>.png) and a map
## sprite (assets/map_sprites/<id>.png) for monsters that don't have hand-made art yet, so a new
## roster addition doesn't render blank next to the fully-arted monsters. The look mirrors the
## Magna-Tiles tiles in gen_art.gd: a backlit stained-glass panel with a faceted gem, tinted by
## the monster's colour. Drop a real PNG at the same path later to override (Portraits/MapSprites
## just load() by convention) — no code change needed. Safe to re-run; it overwrites in place.
##
## Edit MONSTERS below (id + tint, matching gen_content.gd's ROSTER) and run:
##   Godot_console.exe --headless --path <project> --script res://tools/gen_placeholder_monster_art.gd
##
## Only lists monsters that need a placeholder — the older roster ships real portraits/sprites.

const PORTRAIT_DIR := "res://assets/portraits/"
const MAP_SPRITE_DIR := "res://assets/map_sprites/"
const SIZE := 256

# id -> tint (keep in sync with the corresponding gen_content.gd ROSTER rows)
const MONSTERS := {
	"kobold":  Color(0.78, 0.50, 0.28),
	"myconid": Color(0.42, 0.62, 0.50),
	"wisp":    Color(0.60, 0.85, 0.90),
	"imp":     Color(0.85, 0.35, 0.30),
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PORTRAIT_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MAP_SPRITE_DIR))
	for id in MONSTERS:
		var tint: Color = MONSTERS[id]
		_save(_make_portrait(tint), PORTRAIT_DIR + id + ".png")
		_save(_make_map_sprite(tint), MAP_SPRITE_DIR + id + ".png")
	print("gen_placeholder_monster_art: done (%d monsters)" % MONSTERS.size())
	quit()


func _save(img: Image, path: String) -> void:
	var err := img.save_png(ProjectSettings.globalize_path(path))
	assert(err == OK, "failed to save " + path)
	print("wrote ", path)


## A framed, backlit glass panel filled with `tint`, a faceted gem in its centre — the same
## treatment as the tile art, scaled up to a 256px portrait.
func _make_portrait(tint: Color) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var light := tint.lerp(Color.WHITE, 0.30)
	var deep := tint.lerp(Color.BLACK, 0.45)
	var rim := tint.lerp(Color.BLACK, 0.70)
	var frame := 22.0
	var half := SIZE * 0.5
	# Gem: lighter faceted diamond, radius ~40% of the panel.
	var g_hi := tint.lerp(Color.WHITE, 0.55)
	var g_mid := tint.lerp(Color.WHITE, 0.10)
	var g_lo := tint.lerp(Color.BLACK, 0.35)
	var radius := SIZE * 0.34
	for y in SIZE:
		for x in SIZE:
			var col := _panel_pixel(x, y, frame, rim, light, deep, half)
			var dist := absf(x - half) + absf(y - half)   # diamond (manhattan)
			if dist <= radius:
				col = _gem_pixel(x, y, radius, dist, g_hi, g_mid, g_lo, half)
			img.set_pixel(x, y, col)
	return img


## A standalone faceted gem crystal on a transparent field — reads as a token on the dungeon floor.
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
				img.set_pixel(x, y, _gem_pixel(x, y, radius, dist, g_hi, g_mid, g_lo, half))
	return img


## One pixel of a Magna-Tiles panel: dark rim -> beveled frame -> inner lip -> backlit glass.
func _panel_pixel(x: int, y: int, frame_px: float, rim: Color, light: Color, deep: Color,
		half: float) -> Color:
	var fx := float(x)
	var fy := float(y)
	var d_top := fy
	var d_left := fx
	var d_right := float(SIZE - 1) - fx
	var d_bottom := float(SIZE - 1) - fy
	var edge := minf(minf(d_top, d_bottom), minf(d_left, d_right))
	if edge < 3.0:
		return rim
	if edge < frame_px:
		var lit: bool = minf(d_top, d_left) <= minf(d_bottom, d_right)
		var t := (edge - 3.0) / maxf(1.0, frame_px - 3.0)
		var face: Color = light.lerp(Color.WHITE, 0.25) if lit else light.lerp(Color.BLACK, 0.25)
		return face.lerp(light, t)
	if edge < frame_px + 6.0:
		return light.lerp(Color.WHITE, 0.35)
	# Backlit glass: diagonal falloff + centre glow + a specular streak.
	var u := (fx + fy) / (2.0 * float(SIZE - 1))
	var col := light.lerp(deep, clampf(u * 1.15, 0.0, 1.0))
	var r := Vector2(fx - half, fy - half).length() / half
	col = col.lerp(light, clampf(0.35 * (1.0 - r), 0.0, 1.0))
	var s := absf((fx - fy) + 70.0)
	if s < 28.0 and (fx + fy) < float(SIZE):
		col = col.lerp(Color.WHITE, 0.18 * (1.0 - s / 28.0))
	return col


## Overlay a faceted diamond gem, returning the resulting pixel.
func _gem_pixel(x: int, y: int, radius: float, dist: float,
		hi: Color, mid: Color, lo: Color, half: float) -> Color:
	if dist > radius - 10.0:
		return lo                              # gem rim
	if dist > radius - 18.0:
		return mid.lerp(hi, 0.35)              # inner bevel lip
	var col := hi.lerp(mid, clampf(dist / maxf(1.0, radius - 18.0), 0.0, 1.0))
	# Specular dot toward the upper-left facet.
	var spec := Vector2(float(x) - (half - radius * 0.34), float(y) - (half - radius * 0.34))
	var sr := radius * 0.20
	if spec.length() < sr:
		col = col.lerp(Color.WHITE, 0.55 * (1.0 - spec.length() / sr))
	return col
