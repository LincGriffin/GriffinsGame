class_name PowerupArt
extends RefCounted
## Optional art lookup for power-ups, by convention (same shape as Portraits / MapSprites):
##   portrait — assets/powerup_portraits/<id>.png (the large card art in the chooser)
##   sprite   — assets/powerup_sprites/<id>.png   (a small icon)
##
## Both are OPTIONAL: the chooser falls back to the per-effect placeholder icon (UpgradeIcons)
## and then a flat `tint` swatch when neither exists, so the game runs with no power-up art.
## Uploaded via the power-up editor dock (AssetLink) or by dropping a PNG in and re-importing.

const PORTRAIT_DIR := "res://assets/powerup_portraits/"
const SPRITE_DIR := "res://assets/powerup_sprites/"

static var _portraits: Dictionary = {}
static var _sprites: Dictionary = {}


static func portrait_for(id: String) -> Texture2D:
	return _lookup(id, PORTRAIT_DIR, _portraits)


static func sprite_for(id: String) -> Texture2D:
	return _lookup(id, SPRITE_DIR, _sprites)


static func _lookup(id: String, dir: String, cache: Dictionary) -> Texture2D:
	if id.is_empty():
		return null
	if cache.has(id):
		return cache[id]
	var path := dir + id + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	cache[id] = tex
	return tex


## Drop both memos (used by tests; also handy if art is added while the game is running).
static func clear_cache() -> void:
	_portraits = {}
	_sprites = {}
