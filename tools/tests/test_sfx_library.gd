extends "res://tools/tests/_base.gd"
## Sound effects are OPTIONAL, same contract as portraits.gd / map_sprites.gd: a missing id must
## return null so SoundManager's play_sfx() stays a silent no-op.

const SFX_LIBRARY := preload("res://scripts/data/sfx_library.gd")


func before_each() -> void:
	SFX_LIBRARY.clear_cache()


func test_missing_sfx_returns_null() -> void:
	check(SFX_LIBRARY.for_id("definitely_not_a_sound") == null,
		"an id with no audio file returns null rather than erroring")
	check(SFX_LIBRARY.for_id("") == null, "an empty id returns null")


func test_repeated_lookup_is_cached() -> void:
	var first = SFX_LIBRARY.for_id("step")
	var second = SFX_LIBRARY.for_id("step")
	check(first == second, "repeated lookups return the same (cached) result")
