class_name FusionTable
extends RefCounted
## Special monster-merge results (Phase 6; data-driven via the Fusions dock as of later phase).
## MOST parent pairs fuse into a generic "Fused" blend (see MonsterMerge); recipes registered here
## instead become a specific, distinct monster — a "whole new monster" from the player's point of
## view, with its own portrait/map sprite/name.
##
## Recipes live in `assets/data/fusions/*.tres` (FusionRecipeData), edited via the Fusions dock
## (`addons/fusion_editor/`) or bootstrapped by `tools/gen_fusions.gd` — NOT hand-edited here.
## Keyed by the two parent monster ids in SORTED order (FusionRepo.id_for), so pair order doesn't
## matter; a pair CAN be the same id twice (e.g. `griffin_griffin`). An unlisted pair falls
## through to the generic fusion. The index is memoised — call `clear_cache()` after adding/
## editing/removing a recipe in the same process (the dock does this on Save/Delete; tests should
## too, same convention as Portraits/MapSprites).

const FUSION_REPO := preload("res://scripts/data/fusion_repo.gd")

static var _index: Dictionary = {}   # FusionRepo.id_for(a, b) -> result monster id
static var _loaded := false


## The result monster id for a parent pair, or "" if the pair has no special recipe (→ generic).
static func lookup(id_a: String, id_b: String) -> String:
	if id_a.is_empty() or id_b.is_empty():
		return ""
	_ensure_loaded()
	return _index.get(FUSION_REPO.id_for(id_a, id_b), "")


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_index.clear()
	for r in FUSION_REPO.load_all():
		_index[r.id] = r.result_id
	_loaded = true


## Forces the next lookup() to re-read every recipe from disk.
static func clear_cache() -> void:
	_loaded = false
	_index.clear()
