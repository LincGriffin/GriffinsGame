extends "res://tools/tests/_base.gd"
## GameConfig — persistent settings via Godot's ConfigFile. Runs entirely against a scratch
## user:// path so it never touches the real user://config.cfg.

const GAME_CONFIG := preload("res://scripts/data/game_config.gd")
const TEST_PATH := "user://test_game_config.cfg"


func before_each() -> void:
	GAME_CONFIG.clear(TEST_PATH)


func after_each() -> void:
	GAME_CONFIG.clear(TEST_PATH)


func test_missing_file_returns_the_default() -> void:
	eq(GAME_CONFIG.get_value("audio", "SFX", 0.5, TEST_PATH), 0.5,
		"a value with no config file falls back to the caller's default")
	eq(GAME_CONFIG.bus_volume("Music", TEST_PATH), 1.0, "an unset bus volume defaults to full")


func test_set_then_reload_persists() -> void:
	GAME_CONFIG.set_value("audio", "SFX", 0.3, TEST_PATH)
	eq(GAME_CONFIG.get_value("audio", "SFX", 1.0, TEST_PATH), 0.3,
		"a set value survives a fresh load (written to disk)")


func test_setting_one_key_keeps_the_others() -> void:
	GAME_CONFIG.set_value("audio", "SFX", 0.2, TEST_PATH)
	GAME_CONFIG.set_value("audio", "Music", 0.8, TEST_PATH)
	eq(GAME_CONFIG.get_value("audio", "SFX", 1.0, TEST_PATH), 0.2, "SFX kept after Music was set")
	eq(GAME_CONFIG.get_value("audio", "Music", 1.0, TEST_PATH), 0.8, "Music value stored too")


func test_bus_volume_round_trips_and_clamps() -> void:
	GAME_CONFIG.set_bus_volume("SFX", 0.42, TEST_PATH)
	eq(GAME_CONFIG.bus_volume("SFX", TEST_PATH), 0.42, "bus volume round-trips")
	GAME_CONFIG.set_bus_volume("Music", 5.0, TEST_PATH)
	eq(GAME_CONFIG.bus_volume("Music", TEST_PATH), 1.0, "an out-of-range volume is clamped to [0,1]")
