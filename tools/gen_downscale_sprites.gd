extends SceneTree
## Downscales oversized PNGs in a game-asset folder IN PLACE so committed art matches how it's
## actually rendered. The overworld map sprites (assets/map_sprites/) are drawn at the 64px tile
## size (dungeon_view.gd scales each to TILE_SIZE), so multi-megapixel source images are pure repo
## bloat. This caps the longest side at MAX_DIM (keeps aspect, Lanczos), leaving anything already
## small untouched. Full-res masters live in reference/source_art/ (gitignored) — re-run this after
## replacing a map sprite with a fresh full-size image.
##
##   Godot_console.exe --headless --path <project> --script res://tools/gen_downscale_sprites.gd

const DIR := "res://assets/map_sprites/"
const MAX_DIM := 256


func _init() -> void:
	var da := DirAccess.open(DIR)
	if da == null:
		print("gen_downscale_sprites: no such dir ", DIR)
		quit(1)
		return
	var resized := 0
	var skipped := 0
	for f in da.get_files():
		if not f.ends_with(".png"):
			continue
		var res_path := DIR + f
		var img := Image.load_from_file(ProjectSettings.globalize_path(res_path))
		if img == null:
			print("  skip (unreadable): ", f)
			continue
		var w := img.get_width()
		var h := img.get_height()
		var longest: int = max(w, h)
		if longest <= MAX_DIM:
			skipped += 1
			continue
		var s := float(MAX_DIM) / longest
		var nw := int(round(w * s))
		var nh := int(round(h * s))
		img.resize(nw, nh, Image.INTERPOLATE_LANCZOS)
		var err := img.save_png(res_path)
		print("  %-16s %dx%d -> %dx%d [%s]" % [f, w, h, nw, nh, "ok" if err == OK else "ERR %d" % err])
		resized += 1
	print("gen_downscale_sprites: %d resized, %d already small" % [resized, skipped])
	quit()
