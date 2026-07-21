extends "res://tools/tests/_base.gd"
## Overworld movement suite (ported from the original smoke test). Each test spins
## up a fresh overworld instance so state can't leak between cases.

var ow
var player


func before_each() -> void:
	ow = load("res://scenes/overworld/overworld.tscn").instantiate()
	runner.root.add_child(ow)
	await idle()   # let _ready build the room + spawn the player
	await idle()
	player = ow.get_node("Player")


func after_each() -> void:
	ow.queue_free()
	await idle()


func test_walkability() -> void:
	check(player._is_walkable(Vector2i(4, 2)), "floor is walkable")
	check(not player._is_walkable(Vector2i(5, 2)), "wall is blocked")
	check(player._is_walkable(Vector2i(11, 2)), "monster tile is walkable")
	check(not player._is_walkable(Vector2i(-1, -1)), "empty/out-of-bounds is blocked")


func test_wall_blocks_step() -> void:
	var blocked := {"hit": false}
	player.move_blocked.connect(func(_c: Vector2i) -> void: blocked.hit = true)
	player.snap_to_cell(Vector2i(4, 2))          # floor, wall to the right at (5,2)
	await player._try_step(Vector2i.RIGHT)
	eq(player.grid_cell, Vector2i(4, 2), "stayed put when blocked by wall")
	check(blocked.hit, "move_blocked emitted at wall")


func test_monster_triggers_battle() -> void:
	var battle := {"cell": Vector2i(-99, -99)}
	ow.battle_triggered.connect(func(c: Vector2i) -> void: battle.cell = c)
	player.snap_to_cell(Vector2i(10, 2))         # floor, monster to the right at (11,2)
	await player._try_step(Vector2i.RIGHT)
	eq(player.grid_cell, Vector2i(11, 2), "moved onto the monster tile")
	eq(battle.cell, Vector2i(11, 2), "battle_triggered fired at monster cell")


func test_input_actions() -> void:
	check(_matches("move_up", KEY_UP), "move_up matches Up arrow")
	check(_matches("move_up", KEY_W), "move_up matches W")
	check(_matches("move_down", KEY_S), "move_down matches S")
	check(_matches("move_left", KEY_A), "move_left matches A")
	check(_matches("move_right", KEY_RIGHT), "move_right matches Right arrow")
	check(_matches("move_right", KEY_D), "move_right matches D")


func _matches(action: String, physical_keycode: int) -> bool:
	if not InputMap.has_action(action):
		return false
	var ev := InputEventKey.new()
	ev.physical_keycode = physical_keycode
	ev.pressed = true
	return InputMap.event_is_action(ev, action)
