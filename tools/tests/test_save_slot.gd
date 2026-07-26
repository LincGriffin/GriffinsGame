extends "res://tools/tests/_base.gd"
## SaveSlot — the SaveGame Resource round-trip behind SaveManager's save/resume (Phase 19 scaffold).
## Scratch user:// path so it never touches the real user://savegame.tres.

const SAVE_SLOT := preload("res://scripts/data/save_slot.gd")
const SAVE_GAME := preload("res://scripts/data/save_game.gd")
const TEST_PATH := "user://test_savegame.tres"


func before_each() -> void:
	SAVE_SLOT.clear(TEST_PATH)


func after_each() -> void:
	SAVE_SLOT.clear(TEST_PATH)


func test_no_save_initially() -> void:
	check(not SAVE_SLOT.has_save(TEST_PATH), "no save exists before one is written")
	check(SAVE_SLOT.load(TEST_PATH) == null, "loading a missing save returns null, not a crash")


func test_save_then_load_round_trips_fields() -> void:
	var save: SaveGame = SAVE_GAME.new()
	save.starter_id = "bat"
	save.nodes_resolved = 7
	save.battles_fought = 3
	save.cleared_room_ids = [0, 2, 5]
	save.player_cell = Vector2i(4, 9)
	save.recruited = ["rat", "goblin"]
	check(SAVE_SLOT.save(save, TEST_PATH), "save reports success")
	check(SAVE_SLOT.has_save(TEST_PATH), "has_save is true after writing")
	var loaded := SAVE_SLOT.load(TEST_PATH)
	check(loaded is SaveGame, "the loaded resource is a SaveGame")
	eq(loaded.starter_id, "bat", "starter_id round-trips")
	eq(loaded.nodes_resolved, 7, "counters round-trip")
	eq(loaded.cleared_room_ids, [0, 2, 5], "cleared rooms round-trip")
	eq(loaded.player_cell, Vector2i(4, 9), "player cell round-trips")
	eq(loaded.recruited, ["rat", "goblin"], "recruited list round-trips")


func test_clear_removes_the_save() -> void:
	SAVE_SLOT.save(SAVE_GAME.new(), TEST_PATH)
	SAVE_SLOT.clear(TEST_PATH)
	check(not SAVE_SLOT.has_save(TEST_PATH), "clear() removes the save file")


func test_saving_null_is_rejected() -> void:
	check(not SAVE_SLOT.save(null, TEST_PATH), "saving null reports failure instead of writing")
