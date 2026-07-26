extends "res://tools/tests/_base.gd"
## Move visual effects are OPTIONAL, same contract as sfx_library.gd / portraits.gd: a missing or
## blank id must return null so battle.gd's _play_vfx() is a no-op (the move still gets its built-in
## flash/shake/popup). A present id loads its PackedScene.

const VFX_LIBRARY := preload("res://scripts/data/vfx_library.gd")


func before_each() -> void:
	VFX_LIBRARY.clear_cache()


func test_missing_vfx_returns_null() -> void:
	check(VFX_LIBRARY.for_id("definitely_not_an_effect") == null,
		"an id with no scene file returns null rather than erroring")
	check(VFX_LIBRARY.for_id("") == null, "an empty id returns null")


func test_present_effect_loads_a_packed_scene() -> void:
	# gen_vfx.gd ships these; the example moves reference them.
	var scene = VFX_LIBRARY.for_id("slash")
	check(scene is PackedScene, "a shipped effect id resolves to a PackedScene")


func test_repeated_lookup_is_cached() -> void:
	var first = VFX_LIBRARY.for_id("slash")
	var second = VFX_LIBRARY.for_id("slash")
	check(first == second, "repeated lookups return the same (cached) result")
