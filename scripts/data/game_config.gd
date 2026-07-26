class_name GameConfig
extends RefCounted
## Persistent game configuration, backed by Godot's built-in ConfigFile (an INI file in `user://`).
## Static, null-safe, and — like RunHistory / the repos — every function takes an optional `path` so
## tests point at a scratch file instead of the real `user://config.cfg`.
##
## Sections are namespaced so this stays extensible: `[audio]` holds per-bus volumes today; add
## `[gameplay]`, `[video]`, etc. later with no structural change. A missing file or key returns the
## caller's default, so a fresh install behaves exactly like today (nothing persisted yet).

const PATH := "user://config.cfg"
const AUDIO_SECTION := "audio"


## Read a value, or `default` if the file/section/key is absent (or the file is corrupt).
static func get_value(section: String, key: String, default, path: String = PATH):
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return default
	return cfg.get_value(section, key, default)


## Set one value and persist immediately. Loads-modifies-saves so it never clobbers other keys.
static func set_value(section: String, key: String, value, path: String = PATH) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)   # ignore failure — a missing file just starts empty
	cfg.set_value(section, key, value)
	cfg.save(path)


## Delete the config file (a player "reset to defaults", and test teardown).
static func clear(path: String = PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# --- Typed helpers for the known keys (keep call sites out of raw section/key strings) ---

## An audio bus's saved linear volume in [0, 1], defaulting to full (1.0) when unset.
static func bus_volume(bus: String, path: String = PATH) -> float:
	return clampf(float(get_value(AUDIO_SECTION, bus, 1.0, path)), 0.0, 1.0)


static func set_bus_volume(bus: String, linear: float, path: String = PATH) -> void:
	set_value(AUDIO_SECTION, bus, clampf(linear, 0.0, 1.0), path)
