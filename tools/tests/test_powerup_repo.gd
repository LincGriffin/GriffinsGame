extends "res://tools/tests/_base.gd"
## PowerupRepo is the CRUD/validation core behind the power-up editor dock. Runs entirely against
## a scratch `user://` directory so it never touches the real roster in assets/data/powerups/.

const REPO := preload("res://scripts/data/powerup_repo.gd")
const TEST_DIR := "user://test_powerup_repo/"


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


func test_create_writes_a_loadable_powerup() -> void:
	var result = REPO.create("iron_hide", "Iron Hide", TEST_DIR)
	check(result.ok, "create succeeds for a fresh, valid id")
	eq(REPO.list_ids(TEST_DIR), ["iron_hide"], "the new id shows up in the listing")
	var p = REPO.load_one("iron_hide", TEST_DIR)
	check(p != null, "the saved power-up loads back")
	eq(p.id, "iron_hide", "id round-trips")
	eq(p.effect, "hp", "a fresh power-up defaults to the hp effect")
	eq(p.amount, 10, "a fresh power-up gets a default amount")


func test_create_rejects_bad_id_and_duplicates() -> void:
	check(not REPO.create("Iron Hide", "", TEST_DIR).ok, "spaces/capitals are rejected")
	REPO.create("might", "", TEST_DIR)
	check(not REPO.create("might", "", TEST_DIR).ok, "a second power-up can't reuse an existing id")


func test_save_rejects_unknown_effect() -> void:
	var made = REPO.create("thing", "", TEST_DIR)
	var p = made.powerup
	p.effect = "teleport"
	check(not REPO.save(p, "thing", TEST_DIR).ok, "an unknown effect is rejected")
	p.effect = "attack"
	check(REPO.save(p, "thing", TEST_DIR).ok, "a valid effect saves fine")


func test_save_move_effect_requires_a_move_id() -> void:
	var made = REPO.create("teach", "", TEST_DIR)
	var p = made.powerup
	p.effect = "move"
	p.move_id = ""
	check(not REPO.save(p, "teach", TEST_DIR).ok, "a move power-up with no move_id is rejected")
	p.move_id = "drain"
	check(REPO.save(p, "teach", TEST_DIR).ok, "a move power-up with a move_id saves fine")


func test_save_can_rename() -> void:
	var made = REPO.create("boost", "", TEST_DIR)
	var p = made.powerup
	p.id = "big_boost"
	check(REPO.save(p, "boost", TEST_DIR).ok, "rename saves under the new id")
	check(not REPO.id_exists("boost", TEST_DIR), "the old file is gone")
	check(REPO.id_exists("big_boost", TEST_DIR), "the new file exists")


func test_delete_removes_the_file() -> void:
	REPO.create("temp", "", TEST_DIR)
	check(REPO.delete("temp", TEST_DIR), "delete reports success")
	check(not REPO.id_exists("temp", TEST_DIR), "the file is gone")
	check(not REPO.delete("temp", TEST_DIR), "deleting a missing id reports failure")


func test_default_roster_is_present_and_valid() -> void:
	# The generated set (tools/gen_powerups.gd) that the chooser draws from.
	var ids = REPO.list_ids()
	check(ids.has("vitality"), "the real roster includes the vitality (hp) power-up")
	var all = REPO.load_all()
	eq(all.size(), ids.size(), "load_all returns one PowerupData per id")
	for p in all:
		check(REPO.EFFECTS.has(p.effect), "\"%s\" has a valid effect (%s)" % [p.id, p.effect])
