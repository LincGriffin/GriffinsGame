extends "res://tools/tests/_base.gd"
## Map sprites are OPTIONAL art, same contract as portraits.gd: a missing sprite must
## return null so dungeon_view.gd's generic marker tile stays the fallback.

const MAP_SPRITES := preload("res://scripts/data/map_sprites.gd")


func before_each() -> void:
	MAP_SPRITES.clear_cache()


func test_missing_map_sprite_returns_null() -> void:
	check(MAP_SPRITES.for_id("definitely_not_a_monster") == null,
		"an id with no map art returns null rather than erroring")
	check(MAP_SPRITES.for_id("") == null, "an empty id returns null")


func test_for_monster_is_null_safe() -> void:
	check(MAP_SPRITES.for_monster(null) == null, "null MonsterData returns null")
	var slime = load("res://assets/data/monsters/slime.tres")
	var first = MAP_SPRITES.for_monster(slime)
	var second = MAP_SPRITES.for_monster(slime)
	check(first == second, "repeated lookups return the same (cached) result")


func test_every_roster_id_is_looked_up_safely() -> void:
	var ok := true
	for id in ["chicken", "slime", "bat", "rat", "skeleton", "goblin", "spider",
			"golem", "wraith", "gremlin_knob", "griffin", "hydra"]:
		var m = load("res://assets/data/monsters/%s.tres" % id)
		var tex = MAP_SPRITES.for_monster(m)
		if tex != null and not (tex is Texture2D):
			ok = false
	check(ok, "every roster monster resolves to a Texture2D or null")
