class_name FusionRepo
extends RefCounted
## CRUD + validation over monster-merge recipes (`assets/data/fusions/*.tres`), factored out of
## the fusion-editor dock so it has no EditorPlugin dependency and can be unit-tested headless.
## The dock (`addons/fusion_editor/`) is a thin UI shell over this; `scripts/data/fusion_table.gd`
## reads these recipes at fusion time (via `load_all`, memoised — see its `clear_cache()`).
##
## Convention: a recipe's `id` is its filename AND is DERIVED from its (sorted) parent pair —
## `id_for(a, b)` — not freely chosen, so a given pair can only ever have one recipe. Every
## function takes an optional `dir` (defaults to the real roster) so tests can point it at a
## scratch directory instead of touching `assets/data/fusions/`.

const DIR := "res://assets/data/fusions/"


## The two parent ids in a stable (alphabetical) order, so a pair reads the same regardless of
## which parent was picked as "A" vs "B".
static func sorted_pair(a: String, b: String) -> Array:
	var pair := [a, b]
	pair.sort()
	return pair


## The filename/id for a parent pair — also used as the in-memory lookup key by FusionTable.
static func id_for(a: String, b: String) -> String:
	var pair := sorted_pair(a, b)
	return "%s_%s" % [pair[0], pair[1]]


static func list_ids(dir: String = DIR) -> Array[String]:
	var ids: Array[String] = []
	var da := DirAccess.open(dir)
	if da == null:
		return ids
	for f in da.get_files():
		if f.ends_with(".tres"):
			ids.append(f.get_basename())
	ids.sort()
	return ids


static func load_all(dir: String = DIR) -> Array[FusionRecipeData]:
	var out: Array[FusionRecipeData] = []
	for id in list_ids(dir):
		var r := load_one(id, dir)
		if r != null:
			out.append(r)
	return out


static func load_one(id: String, dir: String = DIR) -> FusionRecipeData:
	var path := dir + id + ".tres"
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as FusionRecipeData


static func id_exists(id: String, dir: String = DIR) -> bool:
	return ResourceLoader.exists(dir + id + ".tres")


## True when a DIFFERENT recipe already claims this parent pair (excludes `exclude_id`, so
## re-saving a recipe under its own unchanged pair isn't flagged as a collision).
static func pair_taken(a: String, b: String, exclude_id: String = "", dir: String = DIR) -> bool:
	var id := id_for(a, b)
	return id != exclude_id and id_exists(id, dir)


## Build a fresh recipe from a parent pair + result and save it. Fails if any id is blank or the
## pair already has a recipe.
static func create(parent_a: String, parent_b: String, result_id: String, dir: String = DIR) -> Dictionary:
	var script: GDScript = load("res://scripts/data/fusion_recipe_data.gd")
	var r: FusionRecipeData = script.new()
	r.parent_a = parent_a
	r.parent_b = parent_b
	r.result_id = result_id
	var result := save(r, "", dir)
	if not result.ok:
		return result
	return {"ok": true, "recipe": r}


## Save `r` (its id is recomputed from parent_a/parent_b, not taken from `r.id`). If
## `previous_id` is given and the (recomputed) id differs, the old file is removed after the new
## one is written — handles editing an existing recipe's parents. Fails when a parent/result id
## is blank, or when a DIFFERENT recipe already claims the (new) parent pair.
static func save(r: FusionRecipeData, previous_id: String = "", dir: String = DIR) -> Dictionary:
	if r.parent_a.strip_edges().is_empty() or r.parent_b.strip_edges().is_empty():
		return {"ok": false, "error": "both parents must be set"}
	if r.result_id.strip_edges().is_empty():
		return {"ok": false, "error": "a result monster must be set"}
	r.id = id_for(r.parent_a, r.parent_b)
	if pair_taken(r.parent_a, r.parent_b, previous_id, dir):
		return {"ok": false, "error": "a recipe for %s + %s already exists" % [r.parent_a, r.parent_b]}
	var path := dir + r.id + ".tres"
	var err := ResourceSaver.save(r, path)
	if err != OK:
		return {"ok": false, "error": "save failed (engine error %d)" % err}
	if not previous_id.is_empty() and previous_id != r.id:
		delete(previous_id, dir)
	return {"ok": true}


static func delete(id: String, dir: String = DIR) -> bool:
	if not id_exists(id, dir):
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + id + ".tres")) == OK
