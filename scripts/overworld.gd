extends Node2D
## The dungeon room. Paints the TileMapLayer from an ASCII map, spawns the player,
## and — when the player steps onto a monster or boss tile — launches a Battle as a
## full-screen overlay. When the battle finishes it applies the outcome: award XP
## and clear the tile on a win, show YOU WIN on the boss, GAME OVER on a loss, or
## nothing on a successful flee.

signal battle_triggered(cell: Vector2i)

const SOURCE_ID := 0
const FLOOR := Vector2i(0, 0)
const WALL := Vector2i(1, 0)
const MONSTER := Vector2i(2, 0)
const BOSS := Vector2i(3, 0)

const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")
const REGULAR_ENEMIES: Array[EnemyData] = [
	preload("res://assets/data/enemies/slime.tres"),
	preload("res://assets/data/enemies/bat.tres"),
	preload("res://assets/data/enemies/skeleton.tres"),
]
const BOSS_ENEMY: EnemyData = preload("res://assets/data/enemies/griffin.tres")

# Legend:  '#' wall  '.' floor  'M' monster  'B' boss  'P' player start (a floor)
const ROOM := [
	"####################",
	"#..................#",
	"#....##....M.......#",
	"#....##............#",
	"#........P.........#",
	"#..........####....#",
	"#..........#.......#",
	"#....M.....#....B..#",
	"#..........#.......#",
	"#..................#",
	"#..................#",
	"####################",
]

@onready var tile_map_layer: TileMapLayer = $TileMapLayer
@onready var player: Player = $Player
@onready var _gs: Node = get_node_or_null("/root/GameState")

var _in_battle := false
var _game_over := false
var _active_battle: Battle = null


func _ready() -> void:
	var start := _build_room()
	player.tile_map_layer = tile_map_layer
	player.snap_to_cell(start)
	player.moved.connect(_on_player_moved)


## Paint the ASCII map into the TileMapLayer. Returns the player's start cell.
func _build_room() -> Vector2i:
	var width := ROOM[0].length()
	var start := Vector2i(1, 1)
	for y in ROOM.size():
		var row: String = ROOM[y]
		assert(row.length() == width, "ROOM row %d has wrong width" % y)
		for x in row.length():
			var cell := Vector2i(x, y)
			match row[x]:
				"#":
					_paint(cell, WALL)
				"M":
					_paint(cell, MONSTER)
				"B":
					_paint(cell, BOSS)
				"P":
					_paint(cell, FLOOR)
					start = cell
				_:
					_paint(cell, FLOOR)
	return start


func _paint(cell: Vector2i, atlas: Vector2i) -> void:
	tile_map_layer.set_cell(cell, SOURCE_ID, atlas)


func _on_player_moved(cell: Vector2i) -> void:
	if _in_battle:
		return
	var td := tile_map_layer.get_cell_tile_data(cell)
	if td == null or not td.get_custom_data("monster"):
		return
	battle_triggered.emit(cell)
	var is_boss: bool = td.get_custom_data("boss")
	var enemy: EnemyData = BOSS_ENEMY if is_boss else REGULAR_ENEMIES[randi() % REGULAR_ENEMIES.size()]
	_start_battle(enemy, cell)


func _start_battle(enemy: EnemyData, cell: Vector2i) -> void:
	# No GameState (e.g. a headless unit test) means no live battle — the trigger
	# signal has already fired, which is all such tests check.
	if _gs == null or _in_battle:
		return
	_in_battle = true
	player.set_physics_process(false)
	var battle := BATTLE_SCENE.instantiate()
	battle.setup(enemy)
	battle.finished.connect(_on_battle_finished.bind(cell))
	add_child(battle)
	_active_battle = battle


func _on_battle_finished(result: int, enemy: EnemyData, cell: Vector2i) -> void:
	if _active_battle != null:
		_active_battle.queue_free()
		_active_battle = null
	_in_battle = false

	match result:
		Battle.Result.PLAYER_LOST:
			_show_banner("GAME OVER\nPress R to try again.", Color(0.85, 0.28, 0.28))
			return
		Battle.Result.PLAYER_WON:
			_gs.add_xp(enemy.xp_reward)
			if enemy.is_boss:
				_show_banner("YOU WIN!\nThe Griffin is vanquished.", Color(0.9, 0.75, 0.25))
				return
			_paint(cell, FLOOR)   # clear the defeated monster so it can't retrigger
		Battle.Result.FLED:
			pass

	player.set_physics_process(true)   # resume after a win (non-boss) or a flee


func _show_banner(text: String, color: Color) -> void:
	_game_over = true   # freezes the player (physics stays disabled) until restart
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
	label.add_theme_font_size_override("font_size", 36)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(label)
	add_child(layer)


func _unhandled_input(event: InputEvent) -> void:
	if _game_over and event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_R:
		if _gs != null:
			_gs.new_game()
		get_tree().reload_current_scene()
