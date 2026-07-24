class_name NodeSprites
extends RefCounted
## Optional per-NODE-TYPE overworld art, by convention: `assets/node_sprites/<type>.png`, where
## `<type>` is a map node type — `heal`, `powerup`, `room`, `teleport` (and `battle`/`elite`/`boss`
## if you ever want a generic fallback for those).
##
## Same optional-art contract as Portraits / MapSprites / PowerupArt: memoised, `null` when absent.
## `dungeon_view.gd` draws the most specific art it has over a room's marker tile:
##   monster map sprite (battle/elite/boss) → node sprite (this) → the generated gem marker tile.
##
## SWAPPING ART IS A ONE-FILE DROP: put a PNG named after the node type in `assets/node_sprites/`
## and re-run `--import`. Nothing references these by path except this helper, and no generator or
## data edit is needed. See `assets/node_sprites/README.md`.

const DIR := "res://assets/node_sprites/"

static var _cache: Dictionary = {}


## The sprite for a node type, or null when that type has no art.
static func for_type(type: String) -> Texture2D:
	if type.is_empty():
		return null
	if _cache.has(type):
		return _cache[type]
	var path := DIR + type + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_cache[type] = tex
	return tex


## Drop the memo (used by tests; also handy if art is added while the game is running).
static func clear_cache() -> void:
	_cache = {}
