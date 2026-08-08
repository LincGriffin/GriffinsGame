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

## Art conventions a monster's id is looked up under (Portraits.DIR / MapSprites.DIR) — kept as
## plain constants here (rather than importing those classes) so delete() can clean up a deleted
## monster's leftover art. Parametrized on delete() too, so tests can point them at scratch dirs
## instead of ever touching the real project art.
const PORTRAITS_DIR := "res://assets/portraits/"
const MAP_SPRITES_DIR := "res://assets/map_sprites/"

const MOVE_REPO := preload("res://scripts/data/move_repo.gd")
## Every roster monster with any moves at all includes basic Strike; Guard is the other move
## every tier-0 starter ships with — both exist for the life of the project, so a brand-new
## monster starts able to actually do something in battle instead of an empty moveset.
const DEFAULT_MOVE_IDS := ["strike", "guard"]

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
	# CACHE_MODE_REPLACE forces a fresh read from disk and replaces any stale cached instance —
	# without it, deleting a monster and immediately creating a new one under the SAME id could
	# hand back Godot's cached Resource from before the delete (same path, same in-memory object),
	# still carrying the old stats/moves, instead of the freshly-written file's contents.
	var m := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as MonsterData
	if m != null and m.moves.is_read_only():
		# A monster whose moveset was never explicitly saved (still empty, so `moves` was never
		# written into the .tres) loads back holding the script's shared DEFAULT Array, which
		# Godot marks read-only to stop one instance's edits leaking into every other instance's
		# default. Duplicate it into a private, writable array so callers can freely append/erase.
		m.moves = m.moves.duplicate()
	return m


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
	for move_id in DEFAULT_MOVE_IDS:
		var mv := MOVE_REPO.load_one(move_id)
		if mv != null:
			m.moves.append(mv)
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
		# Only the stale .tres goes away on a rename — the old id's art (if any) is left alone
		# rather than nuked by the full delete() below, since a rename isn't the user asking to
		# discard that monster's art, just to relabel it.
		_delete_tres_only(previous_id, dir)
	return {"ok": true}


## Deletes the monster's .tres AND any art saved under its id (portrait / map sprite) — leaving
## those behind was the cause of a deleted-then-recreated monster appearing to "remember" its old
## art: the new monster reuses the same id, and the convention lookup (Portraits/MapSprites) just
## finds the orphaned file still sitting there. `portraits_dir`/`map_sprites_dir` default to the
## real art conventions but are overridable so tests never touch real project art.
static func delete(id: String, dir: String = DIR, portraits_dir: String = PORTRAITS_DIR,
		map_sprites_dir: String = MAP_SPRITES_DIR) -> bool:
	if not id_exists(id, dir):
		return false
	var ok := _delete_tres_only(id, dir)
	if ok:
		_delete_if_exists(portraits_dir + id + ".png")
		_delete_if_exists(map_sprites_dir + id + ".png")
	return ok


static func _delete_tres_only(id: String, dir: String) -> bool:
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + id + ".tres")) == OK


static func _delete_if_exists(path: String) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_path):
		DirAccess.remove_absolute(abs_path)
