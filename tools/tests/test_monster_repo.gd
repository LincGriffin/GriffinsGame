extends "res://tools/tests/_base.gd"
## MonsterRepo is the CRUD/validation core behind the monster-editor dock. Runs entirely
## against a scratch `user://` directory so it never touches the real roster in
## assets/data/monsters/. MoveRepo (read-only) is exercised against the real move roster.

const REPO := preload("res://scripts/data/monster_repo.gd")
const MOVE_REPO := preload("res://scripts/data/move_repo.gd")
const TEST_DIR := "user://test_monster_repo/"
## Standing in for portraits_dir/map_sprites_dir in delete() tests — NEVER the real art
## conventions, so a test can never delete real project art (e.g. "bat" is a real monster id
## with a real portrait; without this override, deleting the test's scratch "bat" would delete
## assets/portraits/bat.png and assets/map_sprites/bat.png right along with it).
const TEST_ART_DIR := "user://test_monster_repo_art/"


func before_each() -> void:
	_clear_dir(TEST_DIR)
	_clear_dir(TEST_ART_DIR)
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	DirAccess.make_dir_recursive_absolute(TEST_ART_DIR)


func after_each() -> void:
	_clear_dir(TEST_DIR)
	_clear_dir(TEST_ART_DIR)


func _clear_dir(dir: String) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		return
	for f in da.get_files():
		da.remove(f)


func test_create_writes_a_loadable_monster() -> void:
	var result = REPO.create("cave_troll", "Cave Troll", TEST_DIR)
	check(result.ok, "create succeeds for a fresh, valid id")
	eq(REPO.list_ids(TEST_DIR), ["cave_troll"], "the new id shows up in the listing")
	var m = REPO.load_one("cave_troll", TEST_DIR)
	check(m != null, "the saved monster loads back")
	eq(m.id, "cave_troll", "id round-trips")
	eq(m.display_name, "Cave Troll", "display name round-trips")
	eq(m.max_hp, 10, "a fresh monster gets sane default stats")


func test_create_defaults_display_name_from_id() -> void:
	var result = REPO.create("cave_troll", "", TEST_DIR)
	eq(result.monster.display_name, "Cave Troll", "empty display name falls back to a capitalized id")


func test_create_rejects_bad_id_format() -> void:
	check(not REPO.create("Cave Troll", "", TEST_DIR).ok, "spaces/capitals are rejected")
	check(not REPO.create("1troll", "", TEST_DIR).ok, "a leading digit is rejected")
	check(not REPO.create("", "", TEST_DIR).ok, "an empty id is rejected")


func test_create_rejects_duplicate_id() -> void:
	REPO.create("slime", "", TEST_DIR)
	var result = REPO.create("slime", "", TEST_DIR)
	check(not result.ok, "a second monster can't reuse an existing id")


func test_save_can_rename() -> void:
	var made = REPO.create("goblin", "", TEST_DIR)
	var m = made.monster
	m.id = "goblin_chief"
	var result = REPO.save(m, "goblin", TEST_DIR)
	check(result.ok, "rename saves under the new id")
	check(not REPO.id_exists("goblin", TEST_DIR), "the old file is gone")
	check(REPO.id_exists("goblin_chief", TEST_DIR), "the new file exists")


func test_save_rename_rejects_collision_with_another_monster() -> void:
	REPO.create("a", "", TEST_DIR)
	var made_b = REPO.create("b", "", TEST_DIR)
	made_b.monster.id = "a"
	var result = REPO.save(made_b.monster, "b", TEST_DIR)
	check(not result.ok, "renaming onto a different monster's existing id is rejected")
	check(REPO.id_exists("b", TEST_DIR), "the original file is untouched on a rejected rename")


func test_delete_removes_the_file() -> void:
	REPO.create("bat", "", TEST_DIR)
	check(REPO.delete("bat", TEST_DIR, TEST_ART_DIR, TEST_ART_DIR), "delete reports success")
	check(not REPO.id_exists("bat", TEST_DIR), "the file is gone")
	check(not REPO.delete("bat", TEST_DIR, TEST_ART_DIR, TEST_ART_DIR), "deleting a missing id reports failure")


## Leftover art under a deleted monster's id was why deleting a monster then creating a new one
## with the SAME id appeared to "remember" the old art — the convention lookup just found the
## orphaned file still on disk. delete() must clean up both art conventions too.
func test_delete_also_removes_the_monsters_art() -> void:
	REPO.create("cave_troll", "", TEST_DIR)
	var portraits_dir := TEST_ART_DIR + "portraits/"
	var map_sprites_dir := TEST_ART_DIR + "map_sprites/"
	var portrait_path := portraits_dir + "cave_troll.png"
	var sprite_path := map_sprites_dir + "cave_troll.png"
	_write_dummy_file(portrait_path)
	_write_dummy_file(sprite_path)
	REPO.delete("cave_troll", TEST_DIR, portraits_dir, map_sprites_dir)
	check(not FileAccess.file_exists(ProjectSettings.globalize_path(portrait_path)), "the portrait is gone after delete")
	check(not FileAccess.file_exists(ProjectSettings.globalize_path(sprite_path)), "the map sprite is gone after delete")


## A rename (save with a different previous_id) must NOT touch art — only an explicit delete()
## should discard it. Otherwise renaming a monster would silently lose its portrait/map sprite.
func test_rename_does_not_touch_art() -> void:
	var made = REPO.create("goblin", "", TEST_DIR)
	var art_path := TEST_ART_DIR + "goblin.png"
	_write_dummy_file(art_path)
	made.monster.id = "goblin_chief"
	REPO.save(made.monster, "goblin", TEST_DIR)
	check(FileAccess.file_exists(ProjectSettings.globalize_path(art_path)),
		"the old id's art survives a rename (only delete() removes art)")


func _write_dummy_file(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("x")
	f.close()


## A newly created monster should already know a couple of moves — not start with an unusable
## empty moveset a player would face with nothing to press.
func test_create_gives_two_default_moves() -> void:
	var result = REPO.create("cave_troll", "", TEST_DIR)
	eq(result.monster.moves.size(), 2, "a fresh monster starts with two default moves")
	var ids: Array = []
	for mv in result.monster.moves:
		ids.append(String(mv.id))
	check(ids.has("strike"), "default moves include the basic Strike")


## A monster saved with an empty moveset never gets a `moves = [...]` line written to its .tres
## (ResourceSaver omits properties equal to the script default). Reloading it can hand back the
## script's shared default Array, which Godot marks read-only — appending threw "Array is in
## read-only state" for a freshly-created monster in the dock (before create() gave every new
## monster default moves, ANY fresh monster hit this). load_one() must always return a private,
## writable moves array regardless. Built by hand here (not via REPO.create()) so it still isolates
## the empty-moveset case even now that create() always seeds a couple of moves.
func test_a_monster_saved_with_an_empty_moveset_is_appendable_after_reload() -> void:
	var script: GDScript = load("res://scripts/data/monster_data.gd")
	var m: MonsterData = script.new()
	m.id = "cave_troll"
	REPO.save(m, "", TEST_DIR)
	var loaded = REPO.load_one("cave_troll", TEST_DIR)
	check(not loaded.moves.is_read_only(), "moves is writable after a save/load round trip with zero moves")
	var strike := load("res://assets/data/moves/strike.tres")
	loaded.moves.append(strike)
	eq(loaded.moves.size(), 1, "appending to a freshly-reloaded empty moveset works")


func test_move_repo_lists_the_real_move_roster() -> void:
	var ids = MOVE_REPO.list_ids()
	check(ids.has("strike"), "the real move roster includes strike")
	var moves = MOVE_REPO.load_all()
	eq(moves.size(), ids.size(), "load_all returns one MoveData per id")
