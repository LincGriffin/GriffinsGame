extends "res://tools/tests/_base.gd"
## Monster portraits are OPTIONAL art looked up by id. These guard the fallback contract:
## a missing portrait must return null and every screen must still build.

const PORTRAITS := preload("res://scripts/data/portraits.gd")


func before_each() -> void:
	PORTRAITS.clear_cache()


func test_missing_portrait_returns_null() -> void:
	check(PORTRAITS.for_id("definitely_not_a_monster") == null,
		"an id with no art returns null rather than erroring")
	check(PORTRAITS.for_id("") == null, "an empty id returns null")


func test_for_monster_is_null_safe() -> void:
	check(PORTRAITS.for_monster(null) == null, "null MonsterData returns null")
	var slime = load("res://assets/data/monsters/slime.tres")
	# Whether or not art exists yet, the lookup must not error and must be memoised.
	var first = PORTRAITS.for_monster(slime)
	var second = PORTRAITS.for_monster(slime)
	check(first == second, "repeated lookups return the same (cached) result")


func test_every_roster_id_is_looked_up_safely() -> void:
	var ok := true
	for id in ["chicken", "slime", "bat", "rat", "skeleton", "goblin", "spider",
			"golem", "wraith", "gremlin_knob", "griffin", "hydra"]:
		var m = load("res://assets/data/monsters/%s.tres" % id)
		# Null (no art yet) is fine; a crash or a wrong type is not.
		var tex = PORTRAITS.for_monster(m)
		if tex != null and not (tex is Texture2D):
			ok = false
	check(ok, "every roster monster resolves to a Texture2D or null")


## The starter screen must build with or without art — the card falls back to a tint swatch.
func test_starter_select_builds_without_portraits() -> void:
	var sel = load("res://scripts/starter_select.gd").new()
	var options := [
		load("res://assets/data/monsters/chicken.tres"),
		load("res://assets/data/monsters/slime.tres"),
		load("res://assets/data/monsters/bat.tres"),
	]
	sel.setup(options)
	runner.root.add_child(sel)
	await idle()
	var cards := _find_buttons(sel)
	eq(cards.size(), options.size(), "one card button per starter option")
	sel.queue_free()
	await idle()


func _find_buttons(node: Node) -> Array:
	var found: Array = []
	for c in node.get_children():
		if c is Button:
			found.append(c)
		found.append_array(_find_buttons(c))
	return found
