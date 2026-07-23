class_name MapSprites
extends RefCounted
## Optional per-monster overworld/map marker art, looked up by convention:
## `assets/map_sprites/<monster id>.png`. `run.gd` pre-rolls each battle/elite/boss node's
## monster at map-generation time (`_assign_encounters`), so `dungeon_view.gd` can show a
## monster-specific sprite on that room's marker instead of the generic per-type gem.
##
## Map sprites are OPTIONAL, same contract as scripts/data/portraits.gd: absent art falls
## back to the generic marker tile, so the dungeon renders fine with zero map sprites.

const DIR := "res://assets/map_sprites/"

static var _cache: Dictionary = {}


## The map sprite for a monster id, or null when that monster has no map art yet.
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


## Null-safe (a node's "enemy" may be unset for non-encounter node types).
static func for_monster(m) -> Texture2D:
	if m == null:
		return null
	return for_id(String(m.id))


## Drop the memo (used by tests; also handy if art is added while the editor is open).
static func clear_cache() -> void:
	_cache = {}
