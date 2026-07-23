class_name BattleHarness
extends RefCounted
## Drives a REAL `battle.tscn` programmatically — for tests and headless simulation — without
## clicking through the UI or waiting through real wall-clock message pacing. Built because
## `battle.gd` had no scene-level test coverage: its `_ready()` requires a live `/root/RunState`
## and immediately kicks off an async intro gated by real timers, so driving it safely needs a
## shared harness rather than each test reinventing this.
##
## `tree` must be the actual `SceneTree` — pass `runner` from a test (see tools/tests/_base.gd,
## itself a SceneTree) or `self` from a standalone `--script extends SceneTree` tool. It has to
## be the real SceneTree object and not e.g. `runner.root.get_tree()`: calling `.get_tree()` on a
## Node during/near a `--script` SceneTree's own `_init()` returns null (the tree isn't fully
## wired up yet at that point) — the existing tests already dodge this by holding `runner` (the
## SceneTree itself) directly rather than a Node, and this harness follows the same convention.
## `battle.gd` also needs `tree.root` reachable as `/root/...` for its `get_node("/root/RunState")`
## lookup, which holds for both a real game SceneTree and this test/tool one.
##
## Note: `RunState.new_run()` applies the starter HP/attack boost to `party[0]` — same as a real
## run's first pick. That's intentional (this harness simulates real battles, not idealized base
## stats); read `run_state.party[0]` after `start()` if a test needs the actual boosted numbers.
##
## Usage:
##   var h := BattleHarness.new(tree)
##   await h.start([slime, bat], goblin)      # slime leads; auto-picks the lead if not given
##   await h.use_move("strike")               # by MoveData id — waits for the next "beat"
##   await h.switch_to("bat")                 # voluntary switch, by MonsterData id
##   if h.is_finished: print(h.result)        # Battle.Result.PLAYER_WON / PLAYER_LOST / FLED
##   h.teardown()

const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")
const RUN_STATE_SCRIPT := preload("res://autoload/run_state.gd")

enum Beat { COMMAND, PROMPT, FINISHED }

var battle: Battle = null
var run_state = null
var is_finished := false
var result := -1                    # Battle.Result once is_finished
var last_prompt_options: Array = [] # populated whenever a beat resolves to a monster prompt
var last_beat: int = -1             # Beat.COMMAND / PROMPT / FINISHED — which beat fired last

var _tree: SceneTree
var _root: Node
var _owns_run_state := false


func _init(tree: SceneTree) -> void:
	_tree = tree
	_root = tree.root


## Build a RunState-backed party and start a battle against `enemy`. `lead_id` (a MonsterData id)
## picks the opening lead when the party has more than one monster; empty picks the first option.
## `fast` zeroes battle.gd's message-pacing delay (STEP) — leave it true unless a test genuinely
## needs to see real timing.
func start(party: Array, enemy: MonsterData, lead_id: String = "", fast := true) -> void:
	_ensure_run_state()
	run_state.new_run(party[0])
	for i in range(1, party.size()):
		run_state.add_monster(party[i])

	battle = BATTLE_SCENE.instantiate()
	if fast:
		battle.STEP = 0.0
	battle.setup(enemy)
	var armed := _arm_beat()
	_root.add_child(battle)
	await _consume_beat(armed)   # PROMPT (party > 1) or COMMAND (single monster, auto-picked)

	if party.size() > 1:
		var armed2 := _arm_beat()
		battle._choice_made.emit(_pick(last_prompt_options, lead_id))
		await _consume_beat(armed2)   # COMMAND (or FINISHED, if somehow arriving all-dead)


## Use a move by MoveData id on the currently active monster.
func use_move(move_id: String) -> void:
	var mv := _find_move(move_id)
	assert(mv != null, "active monster has no move \"%s\"" % move_id)
	var armed := _arm_beat()
	battle._on_move(mv)
	await _consume_beat(armed)


## Voluntarily switch to another living monster by MonsterData id (empty id cancels instead).
func switch_to(monster_id: String) -> void:
	var armed := _arm_beat()
	battle._on_switch()
	await _consume_beat(armed)   # PROMPT
	var armed2 := _arm_beat()
	battle._choice_made.emit(null if monster_id == "" else _pick(last_prompt_options, monster_id))
	await _consume_beat(armed2)


## Flee — calls the handler directly, so it works even while Battle.FLEE_ENABLED hides the
## button (the harness drives logic, not the UI).
func flee() -> void:
	var armed := _arm_beat()
	battle._on_flee()
	await _consume_beat(armed)


## Resolve a forced switch-on-faint prompt (the beat after use_move()/flee() resolved to PROMPT).
func resolve_prompt(monster_id: String) -> void:
	var armed := _arm_beat()
	battle._choice_made.emit(_pick(last_prompt_options, monster_id))
	await _consume_beat(armed)


## The active monster's MonsterData id, or "" if there's no active monster right now.
func active_id() -> String:
	if battle._active == null or battle._active.source == null:
		return ""
	return String(battle._active.source.id)


## Frees immediately (not queue_free) so a following test's _ensure_run_state() never races a
## pending deletion and finds a stale "RunState" node still attached.
func teardown() -> void:
	if battle != null and is_instance_valid(battle):
		_root.remove_child(battle)
		battle.free()
	if _owns_run_state and run_state != null and is_instance_valid(run_state):
		_root.remove_child(run_state)
		run_state.free()


func _ensure_run_state() -> void:
	run_state = _root.get_node_or_null("RunState")
	if run_state == null:
		run_state = RUN_STATE_SCRIPT.new()
		run_state.name = "RunState"
		_root.add_child(run_state)
		_owns_run_state = true


func _find_move(move_id: String) -> MoveData:
	for mv in battle._active.moves:
		if mv.id == move_id:
			return mv
	return null


func _pick(options: Array, id: String):
	if id == "":
		return options[0]
	for c in options:
		if c.source != null and String(c.source.id) == id:
			return c
	assert(false, "no living option with id \"%s\"" % id)
	return options[0]


## Connect one-shot listeners for all three possible "next beats" BEFORE the caller triggers
## whatever might fire one of them. This matters because a chosen-monster signal
## (`_choice_made`) can resolve synchronously all the way through to `command_ready` when
## there's no real await in between (e.g. cancelling a switch, or the initial lead pick) — connect
## AFTER triggering and that emission is simply missed, hanging the wait forever. Always pair
## with _consume_beat(), and always _arm_beat() before the action that might complete the beat.
func _arm_beat() -> Dictionary:
	var fired := {"i": -1}
	var conn_command := func(): fired.i = Beat.COMMAND
	var conn_prompt := func(options): fired.i = Beat.PROMPT; last_prompt_options = options
	var conn_finished := func(res, _enemy): fired.i = Beat.FINISHED; result = res
	battle.command_ready.connect(conn_command, CONNECT_ONE_SHOT)
	battle.monster_prompt_ready.connect(conn_prompt, CONNECT_ONE_SHOT)
	battle.finished.connect(conn_finished, CONNECT_ONE_SHOT)
	return {"fired": fired, "command": conn_command, "prompt": conn_prompt, "finished": conn_finished}


## Wait for whichever beat _arm_beat() is guarding to fire, then tear down the listeners.
func _consume_beat(armed: Dictionary) -> void:
	var fired: Dictionary = armed.fired
	while fired.i == -1:
		await _tree.process_frame
	if battle.command_ready.is_connected(armed.command):
		battle.command_ready.disconnect(armed.command)
	if battle.monster_prompt_ready.is_connected(armed.prompt):
		battle.monster_prompt_ready.disconnect(armed.prompt)
	if battle.finished.is_connected(armed.finished):
		battle.finished.disconnect(armed.finished)
	last_beat = fired.i
	if fired.i == Beat.FINISHED:
		is_finished = true
