extends "res://tools/tests/_base.gd"
## SaveManager — the single persistence façade. The config/history delegates are covered by
## test_game_config.gd / test_run_history.gd (against scratch paths); here we exercise the
## save/resume delegation hermetically via the optional path param, so no real user:// file is
## touched.

const SAVE_MANAGER := preload("res://scripts/data/save_manager.gd")
const SAVE_GAME := preload("res://scripts/data/save_game.gd")
const TEST_PATH := "user://test_save_manager.tres"


func before_each() -> void:
	SAVE_MANAGER.clear_run_save(TEST_PATH)


func after_each() -> void:
	SAVE_MANAGER.clear_run_save(TEST_PATH)


func test_save_resume_delegation() -> void:
	check(not SAVE_MANAGER.has_run_save(TEST_PATH), "no save to start")
	var save: SaveGame = SAVE_GAME.new()
	save.starter_id = "chicken"
	save.battles_fought = 5
	check(SAVE_MANAGER.save_run(save, TEST_PATH), "save_run delegates to SaveSlot and succeeds")
	check(SAVE_MANAGER.has_run_save(TEST_PATH), "has_run_save sees the written save")
	var loaded := SAVE_MANAGER.load_run(TEST_PATH)
	check(loaded is SaveGame, "load_run returns the SaveGame")
	eq(loaded.starter_id, "chicken", "the saved run round-trips through the façade")
	eq(loaded.battles_fought, 5, "counters round-trip through the façade")
	SAVE_MANAGER.clear_run_save(TEST_PATH)
	check(not SAVE_MANAGER.has_run_save(TEST_PATH), "clear_run_save removes it")
