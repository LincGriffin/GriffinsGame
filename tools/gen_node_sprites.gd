extends SceneTree
## Builds assets/node_sprites/<node type>.png — the overworld art drawn on a map node's marker
## tile (see scripts/data/node_sprites.gd + dungeon_view.gd).
##
## Two sources:
##  1. SOURCES — files copied (and downscaled) from the local third-party pack in
##     assets/thirdparty/. That folder is **gitignored** (the Spirit Claw license allows using and
##     modifying the art in a game but NOT redistributing/repackaging the pack), so only these few
##     derived sprites are committed. Re-running needs the pack present locally.
##  2. Anything the pack has no art for is generated procedurally below (currently the teleport
##     pad — the pack is medieval and ships no portal/pad).
##
## TO SWAP ANY OF THESE: you do NOT need this tool — just drop a PNG named after the node type into
## assets/node_sprites/ and run --import. Edit SOURCES here only if you want the copy reproducible.
##
##   Godot_console.exe --headless --path <project> --script res://tools/gen_node_sprites.gd

const OUT := "res://assets/node_sprites/"
const PACK := "res://assets/thirdparty/ClawAndBlade/"
const MAX_DIM := 96

# node type -> source file inside the third-party pack
const SOURCES := {
	"heal": "GUI/icon/plus_regular.png",                  # a clean "+"
	"powerup": "Icons/Chests/chest_005_gold_closed.png",  # treasure: gold chest
	"room": "Icons/Chests/chest_001_wooden_closed.png",   # treasure: plain wooden chest
}


func _init() -> void:
	var da := DirAccess.open("res://")
	da.make_dir_recursive("assets/node_sprites")

	for type in SOURCES:
		var src: String = ProjectSettings.globalize_path(PACK + SOURCES[type])
		if not FileAccess.file_exists(src):
			print("  %-9s SKIPPED — source missing (is assets/thirdparty/ present?): %s"
				% [type, SOURCES[type]])
			continue
		var img := Image.load_from_file(src)
		if img == null:
			print("  %-9s SKIPPED — unreadable: %s" % [type, SOURCES[type]])
			continue
		_fit(img)
		_save(type, img, SOURCES[type])

	# No portal/teleport art in the pack → generate a rune pad.
	_save("teleport", _teleport_pad(), "generated")
	print("gen_node_sprites: done")
	quit()


## Downscale in place so the longest side is at most MAX_DIM (these render on a 64px tile).
func _fit(img: Image) -> void:
	var longest: int = max(img.get_width(), img.get_height())
	if longest <= MAX_DIM:
		return
	var s := float(MAX_DIM) / longest
	img.resize(int(round(img.get_width() * s)), int(round(img.get_height() * s)),
		Image.INTERPOLATE_LANCZOS)


func _save(type: String, img: Image, origin: String) -> void:
	var dest: String = OUT + type + ".png"
	var err := img.save_png(dest)
	print("  %-9s %dx%d <- %-42s [%s]"
		% [type, img.get_width(), img.get_height(), origin, "ok" if err == OK else "ERR %d" % err])


## A glowing arcane pad: two concentric rings, four ticks, and a soft core — transparent elsewhere.
func _teleport_pad() -> Image:
	var size := MAX_DIM
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(size / 2.0, size / 2.0)
	var ring := Color(0.72, 0.45, 1.0)     # violet
	var core := Color(0.88, 0.80, 1.0)     # pale core
	var outer := size * 0.44
	var inner := size * 0.27
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := p.distance_to(c)
			var a := 0.0
			var col := ring
			if absf(d - outer) < 3.0:
				a = 1.0 - absf(d - outer) / 3.0
			elif absf(d - inner) < 2.5:
				a = (1.0 - absf(d - inner) / 2.5) * 0.9
				col = core
			elif d < size * 0.12:
				a = (1.0 - d / (size * 0.12)) * 0.8
				col = core
			else:
				# four ticks bridging the rings, on the N/E/S/W axes
				var dx := absf(p.x - c.x)
				var dy := absf(p.y - c.y)
				if d > inner and d < outer and (dx < 2.0 or dy < 2.0):
					a = 0.55
			if a > 0.0:
				img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return img
