extends "res://tools/tests/_base.gd"
## FusionRepo is the CRUD/validation core behind the Fusion editor dock. Runs entirely against a
## scratch `user://` directory so it never touches the real recipes in assets/data/fusions/.
## Unlike Monster/Move/Power-up repos, a recipe's id is DERIVED from its (sorted) parent pair, not
## freely chosen — these tests exercise that specifically.

const REPO := preload("res://scripts/data/fusion_repo.gd")
const TEST_DIR := "user://test_fusion_repo/"


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


func test_id_for_sorts_the_pair_so_order_doesnt_matter() -> void:
	eq(REPO.id_for("bat", "slime"), REPO.id_for("slime", "bat"), "id_for is order-independent")
	eq(REPO.id_for("bat", "slime"), "bat_slime", "id is the sorted pair joined by underscore")


func test_id_for_allows_a_self_pair() -> void:
	eq(REPO.id_for("griffin", "griffin"), "griffin_griffin", "a monster can be its own pair partner")


func test_create_writes_a_loadable_recipe() -> void:
	var result = REPO.create("bat", "slime", "wraith", TEST_DIR)
	check(result.ok, "create succeeds for a fresh, valid pair")
	eq(REPO.list_ids(TEST_DIR), ["bat_slime"], "the derived id shows up in the listing")
	var r = REPO.load_one("bat_slime", TEST_DIR)
	check(r != null, "the saved recipe loads back")
	eq(r.parent_a, "bat", "parent_a round-trips")
	eq(r.parent_b, "slime", "parent_b round-trips")
	eq(r.result_id, "wraith", "result_id round-trips")


func test_create_rejects_blank_fields() -> void:
	check(not REPO.create("", "slime", "wraith", TEST_DIR).ok, "a blank parent_a is rejected")
	check(not REPO.create("bat", "", "wraith", TEST_DIR).ok, "a blank parent_b is rejected")
	check(not REPO.create("bat", "slime", "", TEST_DIR).ok, "a blank result is rejected")


func test_create_rejects_a_pair_already_taken() -> void:
	REPO.create("bat", "slime", "wraith", TEST_DIR)
	var second = REPO.create("slime", "bat", "griffin", TEST_DIR)   # same pair, order reversed
	check(not second.ok, "the same pair (in either order) can't have two recipes")


func test_save_can_change_the_result() -> void:
	var made = REPO.create("bat", "slime", "wraith", TEST_DIR)
	var r = made.recipe
	r.result_id = "griffin"
	check(REPO.save(r, r.id, TEST_DIR).ok, "changing just the result saves fine")
	eq(REPO.load_one("bat_slime", TEST_DIR).result_id, "griffin", "the new result round-trips")


func test_save_re_derives_the_id_when_parents_change() -> void:
	var made = REPO.create("bat", "slime", "wraith", TEST_DIR)
	var r = made.recipe
	var old_id: String = r.id
	r.parent_b = "rat"   # now bat+rat instead of bat+slime
	var result = REPO.save(r, old_id, TEST_DIR)
	check(result.ok, "saving with changed parents succeeds")
	check(not REPO.id_exists("bat_slime", TEST_DIR), "the old pair's file is gone")
	check(REPO.id_exists("bat_rat", TEST_DIR), "the new pair's file exists")


func test_delete_removes_the_file() -> void:
	REPO.create("bat", "slime", "wraith", TEST_DIR)
	check(REPO.delete("bat_slime", TEST_DIR), "delete reports success")
	check(not REPO.id_exists("bat_slime", TEST_DIR), "the file is gone")
	check(not REPO.delete("bat_slime", TEST_DIR), "deleting a missing id reports failure")


func test_default_recipes_are_present_and_valid() -> void:
	# The generated set (tools/gen_fusions.gd) that FusionTable reads from.
	var ids = REPO.list_ids()
	check(ids.has("griffin_griffin"), "the real recipe set includes griffin+griffin")
	var all = REPO.load_all()
	eq(all.size(), ids.size(), "load_all returns one FusionRecipeData per id")
	for r in all:
		check(not r.parent_a.is_empty() and not r.parent_b.is_empty() and not r.result_id.is_empty(),
			"\"%s\" has all three fields set" % r.id)
