extends SceneTree
## Headless smoke test for the overworld feature. Verifies, without manual play:
##   - the scene loads and _ready runs
##   - walkability queries (floor / wall / monster / empty)
##   - wall blocking via _try_step
##   - monster tile fires battle_triggered
##   - the move_* input actions match arrow + WASD keys
## Run:  Godot_console.exe --headless --path <project> --script res://tools/smoke_test.gd
## Exit code 0 = all pass, 1 = a check failed.

var _ok := true

func _init() -> void:
	# Safety net so a hung tween can never hang CI.
	create_timer(10.0).timeout.connect(func() -> void:
		push_error("smoke test timed out")
		quit(2))
	_run()


func _run() -> void:
	var ow: Node = load("res://scenes/overworld/overworld.tscn").instantiate()
	root.add_child(ow)
	await process_frame   # let _ready build the room + spawn
	await process_frame

	var player = ow.get_node("Player")

	# --- walkability queries ---
	_check(player._is_walkable(Vector2i(4, 2)), "floor is walkable")
	_check(not player._is_walkable(Vector2i(5, 2)), "wall is blocked")
	_check(player._is_walkable(Vector2i(11, 2)), "monster tile is walkable")
	_check(not player._is_walkable(Vector2i(-1, -1)), "empty/out-of-bounds is blocked")

	# --- wall blocking via a real step ---
	var blocked := {"hit": false}
	player.move_blocked.connect(func(_c: Vector2i) -> void: blocked.hit = true)
	player.snap_to_cell(Vector2i(4, 2))          # floor, wall to the right at (5,2)
	await player._try_step(Vector2i.RIGHT)
	_check(player.grid_cell == Vector2i(4, 2), "stayed put when blocked by wall")
	_check(blocked.hit, "move_blocked emitted at wall")

	# --- monster trigger via a real step ---
	var battle := {"cell": Vector2i(-99, -99)}
	ow.battle_triggered.connect(func(c: Vector2i) -> void: battle.cell = c)
	player.snap_to_cell(Vector2i(10, 2))         # floor, monster to the right at (11,2)
	await player._try_step(Vector2i.RIGHT)
	_check(player.grid_cell == Vector2i(11, 2), "moved onto the monster tile")
	_check(battle.cell == Vector2i(11, 2), "battle_triggered fired at monster cell")

	# --- input map: actions exist and match both arrows and WASD ---
	_check(_matches("move_up", KEY_UP), "move_up matches Up arrow")
	_check(_matches("move_up", KEY_W), "move_up matches W")
	_check(_matches("move_down", KEY_S), "move_down matches S")
	_check(_matches("move_left", KEY_A), "move_left matches A")
	_check(_matches("move_right", KEY_RIGHT), "move_right matches Right arrow")
	_check(_matches("move_right", KEY_D), "move_right matches D")

	print("SMOKE: ", "PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)


func _matches(action: String, physical_keycode: int) -> bool:
	if not InputMap.has_action(action):
		return false
	var ev := InputEventKey.new()
	ev.physical_keycode = physical_keycode
	ev.pressed = true
	return InputMap.event_is_action(ev, action)


func _check(cond: bool, label: String) -> void:
	print(("  ok   " if cond else " FAIL  ") + label)
	if not cond:
		_ok = false
