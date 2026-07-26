class_name SaveSlot
extends RefCounted
## Storage for a single saved run — a SaveGame Resource written to / read from `user://savegame.tres`
## via ResourceSaver/ResourceLoader (Godot's idiomatic typed-save mechanism). Static and null-safe,
## with an optional `path` per function so tests use a scratch file, matching RunHistory/GameConfig.
##
## Text `.tres` (not binary `.res`) so a save is diffable/inspectable, consistent with the rest of
## the project's committed resources. A missing or unreadable file loads as `null` (never crashes).

const PATH := "user://savegame.tres"


## True when a save exists on disk (what a future title-screen "Resume" button checks).
static func has_save(path: String = PATH) -> bool:
	return FileAccess.file_exists(path)


## Write `save` to disk. Returns true on success.
static func save(save: SaveGame, path: String = PATH) -> bool:
	if save == null:
		return false
	return ResourceSaver.save(save, path) == OK


## Load the saved run, or null if there's none (or it failed to parse).
static func load(path: String = PATH) -> SaveGame:
	if not FileAccess.file_exists(path):
		return null
	var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	return res as SaveGame   # null if the file wasn't a SaveGame


## Delete the save (on run end / win / game-over, and in tests).
static func clear(path: String = PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
