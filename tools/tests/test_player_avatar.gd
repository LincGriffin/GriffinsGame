extends "res://tools/tests/_base.gd"
## The dungeon player avatar (Update: player uses its lead monster's sprite + a glow aura).
## The visual result is verified by eye; these just confirm the glow builds and the appearance
## setter is null-safe and doesn't disturb the sprite node.

const PLAYER_SCENE := preload("res://scenes/overworld/player.tscn")
const MONSTER_DATA := preload("res://scripts/data/monster_data.gd")

var player


func before_each() -> void:
	player = PLAYER_SCENE.instantiate()
	runner.root.add_child(player)
	await idle()   # let _ready() build the glow


func after_each() -> void:
	player.queue_free()
	await idle()


func test_player_builds_a_glow_aura() -> void:
	var glow = player.get_node_or_null("Glow")
	check(glow != null, "the player builds a glow aura node behind the sprite")
	if glow != null:
		check(glow.z_index < 0, "the glow renders behind the avatar sprite")


func test_set_appearance_is_null_safe() -> void:
	player.set_monster_appearance(null)   # must not crash
	check(player.get_node_or_null("Sprite2D") != null, "the sprite node survives a null appearance")


func test_set_appearance_keeps_default_when_the_monster_has_no_art() -> void:
	var m = MONSTER_DATA.new()
	m.id = "does_not_exist_xyz"   # no map sprite / portrait on disk
	var before = player.get_node("Sprite2D").texture
	player.set_monster_appearance(m)
	eq(player.get_node("Sprite2D").texture, before,
		"with no art for the monster, the default player sprite is kept")
