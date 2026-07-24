extends "res://tools/tests/_base.gd"
## MoveRepo is the CRUD/validation core behind the move-editor dock. Runs entirely against a
## scratch `user://` directory so it never touches the real roster in assets/data/moves/.

const REPO := preload("res://scripts/data/move_repo.gd")
const TEST_DIR := "user://test_move_repo/"


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


func test_create_writes_a_loadable_move() -> void:
	var result = REPO.create("fire_slash", "Fire Slash", TEST_DIR)
	check(result.ok, "create succeeds for a fresh, valid id")
	eq(REPO.list_ids(TEST_DIR), ["fire_slash"], "the new id shows up in the listing")
	var mv = REPO.load_one("fire_slash", TEST_DIR)
	check(mv != null, "the saved move loads back")
	eq(mv.id, "fire_slash", "id round-trips")
	eq(mv.display_name, "Fire Slash", "display name round-trips")
	eq(mv.kind, "attack", "a fresh move defaults to the attack kind")
	eq(mv.power, 5, "a fresh move gets a default power")


func test_create_rejects_bad_id_and_duplicates() -> void:
	check(not REPO.create("Fire Slash", "", TEST_DIR).ok, "spaces/capitals are rejected")
	check(not REPO.create("1slash", "", TEST_DIR).ok, "a leading digit is rejected")
	REPO.create("slash", "", TEST_DIR)
	check(not REPO.create("slash", "", TEST_DIR).ok, "a second move can't reuse an existing id")


func test_save_rejects_unknown_kind() -> void:
	var made = REPO.create("zap", "", TEST_DIR)
	var mv = made.move
	mv.kind = "banana"
	var result = REPO.save(mv, "zap", TEST_DIR)
	check(not result.ok, "an unknown kind is rejected on save")
	mv.kind = "stun"
	check(REPO.save(mv, "zap", TEST_DIR).ok, "a valid kind saves fine")


func test_save_can_rename() -> void:
	var made = REPO.create("slash", "", TEST_DIR)
	var mv = made.move
	mv.id = "power_slash"
	var result = REPO.save(mv, "slash", TEST_DIR)
	check(result.ok, "rename saves under the new id")
	check(not REPO.id_exists("slash", TEST_DIR), "the old file is gone")
	check(REPO.id_exists("power_slash", TEST_DIR), "the new file exists")


func test_delete_removes_the_file() -> void:
	REPO.create("guard_up", "", TEST_DIR)
	check(REPO.delete("guard_up", TEST_DIR), "delete reports success")
	check(not REPO.id_exists("guard_up", TEST_DIR), "the file is gone")
	check(not REPO.delete("guard_up", TEST_DIR), "deleting a missing id reports failure")


func test_kinds_match_the_move_effect_vocabulary() -> void:
	# Guards against the editor dropdown drifting from what battle.gd resolves.
	for k in ["attack", "guard", "heal", "drain", "buff", "evade", "reflect", "stun", "reckless"]:
		check(REPO.KINDS.has(k), "KINDS includes the \"%s\" effect" % k)
