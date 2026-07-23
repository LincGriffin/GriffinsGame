extends "res://tools/tests/_base.gd"
## AssetLink is the file-copy plumbing behind the monster editor dock's portrait / map-sprite
## Browse & Clear buttons. Runs entirely against scratch `user://` directories.

const ASSET_LINK := preload("res://scripts/data/asset_link.gd")
const SRC_DIR := "user://test_asset_link_src/"
const DEST_DIR := "user://test_asset_link_dest/"
const SRC_FILE := SRC_DIR + "fake.png"


func before_each() -> void:
	_clear_dir(SRC_DIR)
	_clear_dir(DEST_DIR)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SRC_DIR))
	var f := FileAccess.open(SRC_FILE, FileAccess.WRITE)
	f.store_string("not a real png, just bytes to exercise the copy")
	f.close()


func after_each() -> void:
	_clear_dir(SRC_DIR)
	_clear_dir(DEST_DIR)


func _clear_dir(dir: String) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		return
	for f in da.get_files():
		da.remove(f)


func test_import_copies_the_file_to_the_convention_path() -> void:
	var result = ASSET_LINK.import_image(ProjectSettings.globalize_path(SRC_FILE), DEST_DIR, "cave_troll")
	check(result.ok, "import succeeds for an existing source + a saved id")
	check(FileAccess.file_exists(ProjectSettings.globalize_path(DEST_DIR + "cave_troll.png")),
		"the file lands at <dir>/<id>.png")


func test_import_rejects_missing_source() -> void:
	var missing := ProjectSettings.globalize_path(SRC_DIR + "nope.png")
	var result = ASSET_LINK.import_image(missing, DEST_DIR, "cave_troll")
	check(not result.ok, "a missing source file is rejected")


func test_import_rejects_empty_id() -> void:
	var result = ASSET_LINK.import_image(ProjectSettings.globalize_path(SRC_FILE), DEST_DIR, "")
	check(not result.ok, "an empty id (monster not yet saved) is rejected")


func test_clear_removes_the_file() -> void:
	ASSET_LINK.import_image(ProjectSettings.globalize_path(SRC_FILE), DEST_DIR, "cave_troll")
	check(ASSET_LINK.clear_image(DEST_DIR, "cave_troll"), "clear reports success")
	check(not FileAccess.file_exists(ProjectSettings.globalize_path(DEST_DIR + "cave_troll.png")),
		"the file is gone")
	check(not ASSET_LINK.clear_image(DEST_DIR, "cave_troll"), "clearing an already-cleared id reports failure")
