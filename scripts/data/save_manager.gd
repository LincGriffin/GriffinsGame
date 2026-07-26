class_name SaveManager
extends RefCounted
## The single persistence entry point for the game — a thin static façade over three pure-GDScript
## stores, so every call site imports one thing and the storage backend can change in one place:
##   • config     → GameConfig  (ConfigFile,       user://config.cfg)
##   • run history → RunHistory  (JSON,             user://run_history.json)
##   • save/resume → SaveSlot    (SaveGame Resource, user://savegame.tres)  [scaffold, Phase 19]
##
## Deliberately NOT SQLite: Godot 4.7 has no built-in SQLite and a GDExtension binary would break
## the headless doctor/test/hook pipeline. If SQL analytics are ever wanted, swap the delegates here
## for a SQLite-backed store without touching call sites.

const GAME_CONFIG := preload("res://scripts/data/game_config.gd")
const RUN_HISTORY := preload("res://scripts/data/run_history.gd")
const SAVE_SLOT := preload("res://scripts/data/save_slot.gd")


# --- Run history (real playthroughs) ---

static func record_run(entry: Dictionary) -> void:
	RUN_HISTORY.record(entry, RUN_HISTORY.REAL_PATH)


static func history() -> Array:
	return RUN_HISTORY.load_all(RUN_HISTORY.REAL_PATH)


# --- Config ---

static func config_get(section: String, key: String, default):
	return GAME_CONFIG.get_value(section, key, default)


static func config_set(section: String, key: String, value) -> void:
	GAME_CONFIG.set_value(section, key, value)


static func bus_volume(bus: String) -> float:
	return GAME_CONFIG.bus_volume(bus)


static func set_bus_volume(bus: String, linear: float) -> void:
	GAME_CONFIG.set_bus_volume(bus, linear)


# --- Save / resume (scaffold — storage works + tested; run.gd wiring is the follow-up phase) ---
# The optional `path` (default = the real SaveSlot.PATH) lets tests run against a scratch file; call
# sites in the game omit it.

static func has_run_save(path: String = SAVE_SLOT.PATH) -> bool:
	return SAVE_SLOT.has_save(path)


static func save_run(save: SaveGame, path: String = SAVE_SLOT.PATH) -> bool:
	return SAVE_SLOT.save(save, path)


static func load_run(path: String = SAVE_SLOT.PATH) -> SaveGame:
	return SAVE_SLOT.load(path)


static func clear_run_save(path: String = SAVE_SLOT.PATH) -> void:
	SAVE_SLOT.clear(path)
