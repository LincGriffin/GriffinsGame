extends Node
## The run controller — the game's main scene. Owns one roguelike run: pick a starter,
## generate a branching node-map, and resolve the node you pick (battle / heal /
## power-up / teleport / boss) until the Griffin falls (win) or the party is wiped
## (game over → press R for a fresh run). Nothing persists between runs.
##
## The node-map replaces the old single walkable room as the overworld. The room engine
## (overworld.gd / player.gd) stays in the repo for the upcoming hybrid room nodes.

const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")
const STARTER_SELECT := preload("res://scripts/starter_select.gd")
const MAP_VIEW := preload("res://scripts/map/map_view.gd")
const MAP_GENERATOR := preload("res://scripts/map/map_generator.gd")

const REGULAR_ENEMIES: Array[MonsterData] = [
	preload("res://assets/data/monsters/slime.tres"),
	preload("res://assets/data/monsters/bat.tres"),
	preload("res://assets/data/monsters/skeleton.tres"),
]
const BOSS_ENEMY: MonsterData = preload("res://assets/data/monsters/griffin.tres")

const POWERUP_HP := 6   # +max HP granted by a power-up node

var _gs: Node
var _rng := RandomNumberGenerator.new()
var _map: Dictionary = {}
var _reachable: Array = []
var _cleared: Array = []
var _pre_reachable: Array = []
var _map_layer: CanvasLayer
var _view = null
var _active_battle: Battle = null
var _busy := false
var _ended := false


func _ready() -> void:
	_rng.randomize()
	_gs = get_node_or_null("/root/RunState")
	if _gs == null:
		return   # headless / test context: no live run
	_map_layer = CanvasLayer.new()
	add_child(_map_layer)
	if _gs.has_living():
		_begin_run()
	else:
		_show_starter_select()


func _show_starter_select() -> void:
	var sel: StarterSelect = STARTER_SELECT.new()
	sel.setup(REGULAR_ENEMIES)
	sel.chosen.connect(func(m):
		_gs.new_run(m)
		sel.queue_free()
		_begin_run())
	add_child(sel)


func _begin_run() -> void:
	_map = MAP_GENERATOR.new().generate(_rng)
	_cleared = []
	_reachable = _map["start_row_nodes"].duplicate()
	_ended = false
	_busy = false
	if _view != null:
		_view.queue_free()
	_view = MAP_VIEW.new()
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.node_selected.connect(_on_node_selected)
	_map_layer.add_child(_view)
	_view.setup(_map)
	_view.set_state(_reachable, _cleared)


func _on_node_selected(id: int) -> void:
	if _busy or _ended or not _reachable.has(id):
		return
	_busy = true
	_pre_reachable = _reachable.duplicate()
	_view.set_state([], _cleared)   # lock the map while the node resolves
	var node: Dictionary = _map["nodes"][id]
	match node["type"]:
		"battle":
			_do_battle(id, REGULAR_ENEMIES[_rng.randi_range(0, REGULAR_ENEMIES.size() - 1)])
		"boss":
			_do_battle(id, BOSS_ENEMY)
		"heal":
			_heal_party()
			_advance(id)
		"powerup":
			_apply_powerup()
			_advance(id)
		"teleport":
			_teleport(id)
		_:
			_advance(id)


func _do_battle(id: int, enemy: MonsterData) -> void:
	if not _gs.has_living():
		_game_over()
		return
	var battle := BATTLE_SCENE.instantiate()
	battle.setup(enemy)
	battle.finished.connect(_on_battle_finished.bind(id))
	add_child(battle)
	_active_battle = battle


func _on_battle_finished(result: int, enemy: MonsterData, id: int) -> void:
	if _active_battle != null:
		_active_battle.queue_free()
		_active_battle = null
	_gs.prune_dead()
	match result:
		Battle.Result.PLAYER_LOST:
			_game_over()
		Battle.Result.PLAYER_WON:
			if enemy.is_boss:
				_win()
			else:
				_gs.add_monster(enemy)
				_advance(id)
		Battle.Result.FLED:
			_busy = false
			_reachable = _pre_reachable   # fled — stay put and pick another node
			_view.set_state(_reachable, _cleared)


func _advance(id: int) -> void:
	if not _cleared.has(id):
		_cleared.append(id)
	var node: Dictionary = _map["nodes"][id]
	_reachable = []
	for t in node["to"]:
		if not _cleared.has(t):
			_reachable.append(t)
	_busy = false
	_view.set_state(_reachable, _cleared)


func _teleport(id: int) -> void:
	if not _cleared.has(id):
		_cleared.append(id)
	var node: Dictionary = _map["nodes"][id]
	# Jump ~2 rows ahead, but never straight onto the boss row.
	var target_row: int = mini(int(node["row"]) + 2, int(_map["rows"]) - 2)
	var jump: Array = []
	for n in _map["nodes"]:
		if n["row"] == target_row and not _cleared.has(n["id"]):
			jump.append(n["id"])
	if jump.is_empty():
		for t in node["to"]:
			if not _cleared.has(t):
				jump.append(t)
	_reachable = jump
	_busy = false
	_view.set_state(_reachable, _cleared)


func _heal_party() -> void:
	for c in _gs.party:
		c.hp = c.max_hp


func _apply_powerup() -> void:
	# A small, permanent +max HP to the whole party (healed by the bonus amount).
	for c in _gs.party:
		c.max_hp += POWERUP_HP
		c.hp += POWERUP_HP


func _win() -> void:
	_show_banner("YOU WIN!\nThe Griffin is vanquished.", Color(0.9, 0.75, 0.25))


func _game_over() -> void:
	_show_banner("GAME OVER\nPress R for a new run.", Color(0.85, 0.28, 0.28))


func _show_banner(text: String, color: Color) -> void:
	_ended = true
	_busy = true
	var layer := CanvasLayer.new()
	layer.layer = 20
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 40)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(label)
	add_child(layer)


func _unhandled_input(event: InputEvent) -> void:
	if _ended and event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_R:
		if _gs != null:
			_gs.new_run(null)   # clear the party; _ready will prompt for a new starter
		get_tree().reload_current_scene()
