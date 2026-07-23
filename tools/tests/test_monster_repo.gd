extends "res://tools/tests/_base.gd"
## MonsterRepo is the CRUD/validation core behind the monster-editor dock. Runs entirely
## against a scratch `user://` directory so it never touches the real roster in
## assets/data/monsters/. MoveRepo (read-only) is exercised against the real move roster.

const REPO := preload("res://scripts/data/monster_repo.gd")
const MOVE_REPO := preload("res://scripts/data/move_repo.gd")
const TEST_DIR := "user://test_monster_repo/"


func before_each() -> void:
	_clear_dir()
	DirAccess.make_dir_recursive_absolute(TEST_DIR)


func after_each() -> void:
	_clear_dir()


func _clear_dir() -> void:
	var da := DirAccess.open(TEST_DIR)
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
	check(REPO.delete("bat", TEST_DIR), "delete reports success")
	check(not REPO.id_exists("bat", TEST_DIR), "the file is gone")
	check(not REPO.delete("bat", TEST_DIR), "deleting a missing id reports failure")


func test_move_repo_lists_the_real_move_roster() -> void:
	var ids = MOVE_REPO.list_ids()
	check(ids.has("strike"), "the real move roster includes strike")
	var moves = MOVE_REPO.load_all()
	eq(moves.size(), ids.size(), "load_all returns one MoveData per id")
