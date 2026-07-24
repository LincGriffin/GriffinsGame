extends "res://tools/tests/_base.gd"
## NodeSprites: per-node-type overworld art, looked up by convention with a null-safe miss
## (dungeon_view falls back to the monster map sprite / the generated gem marker).

const NODE_SPRITES := preload("res://scripts/data/node_sprites.gd")


func before_each() -> void:
	NODE_SPRITES.clear_cache()


func test_the_shipped_node_sprites_exist() -> void:
	for type in ["heal", "powerup", "room", "teleport"]:
		check(NODE_SPRITES.for_type(type) != null,
			"the '%s' node sprite is present, so its marker shows art" % type)


func test_a_type_with_no_art_returns_null() -> void:
	check(NODE_SPRITES.for_type("not_a_node_type") == null,
		"an unknown node type returns null rather than erroring")
	check(NODE_SPRITES.for_type("") == null, "an empty type returns null")


func test_lookup_is_memoised() -> void:
	var first = NODE_SPRITES.for_type("heal")
	var second = NODE_SPRITES.for_type("heal")
	check(first == second, "repeated lookups return the same cached texture")


func test_encounter_types_have_no_generic_sprite() -> void:
	# battle/elite/boss deliberately ship none — they use the monster's own map sprite instead.
	for type in ["battle", "elite", "boss"]:
		check(NODE_SPRITES.for_type(type) == null,
			"'%s' has no generic node sprite (monster map sprite is used)" % type)
