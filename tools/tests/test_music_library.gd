extends "res://tools/tests/_base.gd"
## Music tracks are OPTIONAL, same contract as sfx_library.gd: a missing id must return null so
## SoundManager's play_music() stays a silent no-op (keeps whatever was already playing).

const MUSIC_LIBRARY := preload("res://scripts/data/music_library.gd")


func before_each() -> void:
	MUSIC_LIBRARY.clear_cache()


func test_missing_track_returns_null() -> void:
	check(MUSIC_LIBRARY.for_id("definitely_not_a_track") == null,
		"an id with no audio file returns null rather than erroring")
	check(MUSIC_LIBRARY.for_id("") == null, "an empty id returns null")


func test_repeated_lookup_is_cached() -> void:
	var first = MUSIC_LIBRARY.for_id("dungeon")
	var second = MUSIC_LIBRARY.for_id("dungeon")
	check(first == second, "repeated lookups return the same (cached) result")
