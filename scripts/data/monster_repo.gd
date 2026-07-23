class_name MonsterRepo
extends RefCounted
## CRUD + validation over the monster roster (`assets/data/monsters/*.tres`), factored out
## of the monster-editor dock so it has no EditorPlugin dependency and can be unit-tested
## headless. The dock (`addons/monster_editor/`) is a thin UI shell over this.
##
## Convention (matches gen_content.gd): a monster's `id` is also its filename, lowercase
## snake_case, and must be unique across the roster.
##
## Every function takes an optional `dir` (defaults to the real roster) so tests can point
## it at a scratch directory instead of touching `assets/data/monsters/`.

const DIR := "res://assets/data/monsters/"
const ID_REGEX_PATTERN := "^[a-z][a-z0-9_]*$"

static var _id_regex: RegEx = null


## Every monster id currently on disk, sorted.
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


## Every monster on disk, loaded, sorted by id.
static func load_all(dir: String = DIR) -> Array[MonsterData]:
	var out: Array[MonsterData] = []
	for id in list_ids(dir):
		var m := load_one(id, dir)
		if m != null:
			out.append(m)
	return out


static func load_one(id: String, dir: String = DIR) -> MonsterData:
	var path := dir + id + ".tres"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as MonsterData


static func id_exists(id: String, dir: String = DIR) -> bool:
	return ResourceLoader.exists(dir + id + ".tres")


## Lowercase snake_case, non-empty. (Uniqueness is checked separately — a rename needs to
## allow a monster's own current id.)
static func is_valid_id_format(id: String) -> bool:
	if _id_regex == null:
		_id_regex = RegEx.new()
		_id_regex.compile(ID_REGEX_PATTERN)
	return _id_regex.search(id) != null


## Build a fresh monster with sane defaults and save it. Fails if the id is malformed or
## already taken.
static func create(id: String, display_name: String = "", dir: String = DIR) -> Dictionary:
	if not is_valid_id_format(id):
		return {"ok": false, "error": "id must be lowercase snake_case (e.g. \"cave_troll\")"}
	if id_exists(id, dir):
		return {"ok": false, "error": "a monster with id \"%s\" already exists" % id}
	var script: GDScript = load("res://scripts/data/monster_data.gd")
	var m: MonsterData = script.new()
	m.id = id
	m.display_name = display_name if not display_name.is_empty() else id.capitalize()
	m.max_hp = 10
	m.attack = 5
	m.defense = 2
	m.speed = 5
	m.tint = Color.WHITE
	var result := save(m, "", dir)
	if not result.ok:
		return result
	return {"ok": true, "monster": m}


## Save `m` under its current `id`. If `previous_id` is given and differs, the old file is
## removed after the new one is written (a rename). Fails if the id is malformed, or if the
## (new) id collides with a *different* monster already on disk.
static func save(m: MonsterData, previous_id: String = "", dir: String = DIR) -> Dictionary:
	if not is_valid_id_format(m.id):
		return {"ok": false, "error": "id must be lowercase snake_case (e.g. \"cave_troll\")"}
	if m.id != previous_id and id_exists(m.id, dir):
		return {"ok": false, "error": "a monster with id \"%s\" already exists" % m.id}
	var path := dir + m.id + ".tres"
	var err := ResourceSaver.save(m, path)
	if err != OK:
		return {"ok": false, "error": "save failed (engine error %d)" % err}
	if not previous_id.is_empty() and previous_id != m.id:
		delete(previous_id, dir)
	return {"ok": true}


static func delete(id: String, dir: String = DIR) -> bool:
	if not id_exists(id, dir):
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + id + ".tres")) == OK
