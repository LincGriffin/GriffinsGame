class_name PowerupRepo
extends RefCounted
## CRUD + validation over the power-up roster (`assets/data/powerups/*.tres`), factored out of the
## power-up editor dock so it has no EditorPlugin dependency and can be unit-tested headless. The
## dock (`addons/powerup_editor/`) is a thin UI shell over this; run.gd's power-up chooser
## (`_build_upgrade_options`) draws its offered upgrades from these resources.
##
## Convention (matches gen_powerups.gd): a power-up's `id` is also its filename, lowercase
## snake_case, and must be unique. Every function takes an optional `dir` (defaults to the real
## roster) so tests can point it at a scratch directory.

const DIR := "res://assets/data/powerups/"
const ID_REGEX_PATTERN := "^[a-z][a-z0-9_]*$"

## Applyable effects (see PowerupData / run.gd::_grant_upgrade). The editor offers these in a
## dropdown so a hand-typed effect can't drift from what the game applies.
const EFFECTS: Array[String] = ["hp", "attack", "defense", "move"]

static var _id_regex: RegEx = null


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


static func load_all(dir: String = DIR) -> Array[PowerupData]:
	var out: Array[PowerupData] = []
	for id in list_ids(dir):
		var p := load_one(id, dir)
		if p != null:
			out.append(p)
	return out


static func load_one(id: String, dir: String = DIR) -> PowerupData:
	var path := dir + id + ".tres"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as PowerupData


static func id_exists(id: String, dir: String = DIR) -> bool:
	return ResourceLoader.exists(dir + id + ".tres")


static func is_valid_id_format(id: String) -> bool:
	if _id_regex == null:
		_id_regex = RegEx.new()
		_id_regex.compile(ID_REGEX_PATTERN)
	return _id_regex.search(id) != null


## Build a fresh power-up with sane defaults and save it. Fails if the id is malformed or taken.
static func create(id: String, display_name: String = "", dir: String = DIR) -> Dictionary:
	if not is_valid_id_format(id):
		return {"ok": false, "error": "id must be lowercase snake_case (e.g. \"iron_hide\")"}
	if id_exists(id, dir):
		return {"ok": false, "error": "a power-up with id \"%s\" already exists" % id}
	var script: GDScript = load("res://scripts/data/powerup_data.gd")
	var p: PowerupData = script.new()
	p.id = id
	p.display_name = display_name if not display_name.is_empty() else id.capitalize()
	p.effect = "hp"
	p.amount = 10
	var result := save(p, "", dir)
	if not result.ok:
		return result
	return {"ok": true, "powerup": p}


## Save `p` under its current `id`. If `previous_id` differs, the old file is removed (rename).
## Fails on a malformed id, an unknown effect, a "move" effect with no `move_id`, or an id that
## collides with a *different* power-up already on disk.
static func save(p: PowerupData, previous_id: String = "", dir: String = DIR) -> Dictionary:
	if not is_valid_id_format(p.id):
		return {"ok": false, "error": "id must be lowercase snake_case (e.g. \"iron_hide\")"}
	if not EFFECTS.has(p.effect):
		return {"ok": false, "error": "effect must be one of: " + ", ".join(EFFECTS)}
	if p.effect == "move" and p.move_id.strip_edges().is_empty():
		return {"ok": false, "error": "a \"move\" power-up needs a move_id (which move to teach)"}
	if p.id != previous_id and id_exists(p.id, dir):
		return {"ok": false, "error": "a power-up with id \"%s\" already exists" % p.id}
	var path := dir + p.id + ".tres"
	var err := ResourceSaver.save(p, path)
	if err != OK:
		return {"ok": false, "error": "save failed (engine error %d)" % err}
	if not previous_id.is_empty() and previous_id != p.id:
		delete(previous_id, dir)
	return {"ok": true}


static func delete(id: String, dir: String = DIR) -> bool:
	if not id_exists(id, dir):
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + id + ".tres")) == OK
