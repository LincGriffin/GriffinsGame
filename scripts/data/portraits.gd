class_name Portraits
extends RefCounted
## Monster portrait lookup, by convention: `assets/portraits/<monster id>.png`.
##
## Portraits are OPTIONAL. Every screen falls back to the monster's flat `tint` colour when
## the file is absent, so the game runs fine with no portrait art at all. To add art you just
## drop a PNG named after the monster's `id` into `assets/portraits/` and re-run `--import` —
## no generator re-run and no data edit, because nothing references portraits by path except
## this helper. See `assets/portraits/README.md` for the spec and the id list.

const DIR := "res://assets/portraits/"

static var _cache: Dictionary = {}


## The portrait for a monster id, or null when that monster has no art yet.
static func for_id(id: String) -> Texture2D:
	if id.is_empty():
		return null
	if _cache.has(id):
		return _cache[id]
	var path := DIR + id + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_cache[id] = tex
	return tex


## The portrait for a MonsterData (null-safe — combatants built with make() have no source).
static func for_monster(m) -> Texture2D:
	if m == null:
		return null
	return for_id(String(m.id))


## Drop the memo (used by tests; also handy if art is added while the game is running).
static func clear_cache() -> void:
	_cache = {}
