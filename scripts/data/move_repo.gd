class_name MoveRepo
extends RefCounted
## CRUD + validation over the move roster (`assets/data/moves/*.tres`), factored out of the
## move-editor dock so it has no EditorPlugin dependency and can be unit-tested headless. The
## dock (`addons/move_editor/`) is a thin UI shell over this. The monster-editor dock also uses
## the read-only listing here to offer moves for a monster's moveset.
##
## Convention (matches gen_moves.gd): a move's `id` is also its filename, lowercase snake_case,
## and must be unique across the roster.
##
## Every function takes an optional `dir` (defaults to the real roster) so tests can point it at
## a scratch directory instead of touching `assets/data/moves/`.

const DIR := "res://assets/data/moves/"
const ID_REGEX_PATTERN := "^[a-z][a-z0-9_]*$"

## The move effect kinds battle.gd understands (see MoveData / scripts/battle.gd). The editor
## offers these in a dropdown so a hand-typed kind can't drift from what the battle resolves.
const KINDS: Array[String] = [
	"attack", "guard", "heal", "drain", "buff", "evade", "reflect", "stun", "reckless",
]

static var _id_regex: RegEx = null


## Every move id currently on disk, sorted.
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


## Every move on disk, loaded, sorted by id.
static func load_all(dir: String = DIR) -> Array[MoveData]:
	var out: Array[MoveData] = []
	for id in list_ids(dir):
		var mv := load_one(id, dir)
		if mv != null:
			out.append(mv)
	return out


static func load_one(id: String, dir: String = DIR) -> MoveData:
	var path := dir + id + ".tres"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as MoveData


static func id_exists(id: String, dir: String = DIR) -> bool:
	return ResourceLoader.exists(dir + id + ".tres")


## Lowercase snake_case, non-empty. (Uniqueness is checked separately — a rename needs to allow
## a move's own current id.)
static func is_valid_id_format(id: String) -> bool:
	if _id_regex == null:
		_id_regex = RegEx.new()
		_id_regex.compile(ID_REGEX_PATTERN)
	return _id_regex.search(id) != null


## Build a fresh move with sane defaults and save it. Fails if the id is malformed or taken.
static func create(id: String, display_name: String = "", dir: String = DIR) -> Dictionary:
	if not is_valid_id_format(id):
		return {"ok": false, "error": "id must be lowercase snake_case (e.g. \"fire_slash\")"}
	if id_exists(id, dir):
		return {"ok": false, "error": "a move with id \"%s\" already exists" % id}
	var script: GDScript = load("res://scripts/data/move_data.gd")
	var mv: MoveData = script.new()
	mv.id = id
	mv.display_name = display_name if not display_name.is_empty() else id.capitalize()
	mv.kind = "attack"
	mv.power = 5
	var result := save(mv, "", dir)
	if not result.ok:
		return result
	return {"ok": true, "move": mv}


## Save `mv` under its current `id`. If `previous_id` is given and differs, the old file is
## removed after the new one is written (a rename). Fails if the id is malformed, if `kind` isn't
## one battle.gd understands, or if the (new) id collides with a *different* move already on disk.
static func save(mv: MoveData, previous_id: String = "", dir: String = DIR) -> Dictionary:
	if not is_valid_id_format(mv.id):
		return {"ok": false, "error": "id must be lowercase snake_case (e.g. \"fire_slash\")"}
	if not KINDS.has(mv.kind):
		return {"ok": false, "error": "kind must be one of: " + ", ".join(KINDS)}
	if mv.id != previous_id and id_exists(mv.id, dir):
		return {"ok": false, "error": "a move with id \"%s\" already exists" % mv.id}
	var path := dir + mv.id + ".tres"
	var err := ResourceSaver.save(mv, path)
	if err != OK:
		return {"ok": false, "error": "save failed (engine error %d)" % err}
	if not previous_id.is_empty() and previous_id != mv.id:
		delete(previous_id, dir)
	return {"ok": true}


static func delete(id: String, dir: String = DIR) -> bool:
	if not id_exists(id, dir):
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + id + ".tres")) == OK
