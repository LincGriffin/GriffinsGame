class_name VfxLibrary
extends RefCounted
## Visual-effect lookup, by convention: `assets/vfx/<vfx id>.{tscn,scn}`.
##
## An effect is a self-contained PackedScene (a Node2D + CPUParticles2D, see tools/gen_vfx.gd)
## that battle.gd instantiates at a target/caster anchor when a move with that `vfx` id is used.
## Effects are OPTIONAL — same contract as scripts/data/sfx_library.gd / portraits.gd: a missing
## (or blank) id resolves to null and battle just plays its built-in flash/shake/popup feedback,
## so the game runs fine with zero vfx files present. Moves share an effect by naming the same id.
## See assets/vfx/README.md for the scene spec.

const DIR := "res://assets/vfx/"
const EXTENSIONS: Array[String] = ["tscn", "scn"]

static var _cache: Dictionary = {}


## The effect scene for a vfx id, or null when no matching file exists yet.
static func for_id(id: String) -> PackedScene:
	if id.is_empty():
		return null
	if _cache.has(id):
		return _cache[id]
	var scene: PackedScene = null
	for ext in EXTENSIONS:
		var path := DIR + id + "." + ext
		if ResourceLoader.exists(path):
			scene = load(path) as PackedScene
			break
	_cache[id] = scene
	return scene


## Drop the memo (used by tests; also handy if effects are added while the game is running).
static func clear_cache() -> void:
	_cache = {}
