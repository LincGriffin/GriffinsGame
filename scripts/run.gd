extends Node
## The run controller — the game's main scene. Owns one roguelike run and renders it as a
## WALKABLE dungeon: generate a branching map, hand it to a DungeonView (rooms + corridors),
## and resolve a node when the player walks into its room. The whole dungeon is open and
## backtrackable, so you can reach every node if you like. Win the boss → YOU WIN; a party
## wipe → GAME OVER (press R for a fresh run). Nothing persists between runs.

const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")
const STARTER_SELECT := preload("res://scripts/starter_select.gd")
const TITLE_SCREEN := preload("res://scripts/title_screen.gd")
const DUNGEON_VIEW := preload("res://scripts/map/dungeon_view.gd")
const MAP_GENERATOR := preload("res://scripts/map/map_generator.gd")

# The wild pool spans difficulty tiers 0..3; the run draws depth-appropriate monsters
# (see _pick_wild). Starters are the three tier-0 monsters.
const WILD_ENEMIES: Array[MonsterData] = [
	preload("res://assets/data/monsters/chicken.tres"),
	preload("res://assets/data/monsters/slime.tres"),
	preload("res://assets/data/monsters/bat.tres"),
	preload("res://assets/data/monsters/rat.tres"),
	preload("res://assets/data/monsters/skeleton.tres"),
	preload("res://assets/data/monsters/goblin.tres"),
	preload("res://assets/data/monsters/spider.tres"),
	preload("res://assets/data/monsters/golem.tres"),
	preload("res://assets/data/monsters/wraith.tres"),
]
# The three weakest (tier 0) are offered as run-start starters.
const STARTER_ENEMIES: Array[MonsterData] = [
	preload("res://assets/data/monsters/chicken.tres"),
	preload("res://assets/data/monsters/slime.tres"),
	preload("res://assets/data/monsters/bat.tres"),
]
# Elite encounters — tougher fights that recruit a strong monster and heal the party.
const ELITE_ENEMIES: Array[MonsterData] = [
	preload("res://assets/data/monsters/gremlin_knob.tres"),
	preload("res://assets/data/monsters/griffin.tres"),
]
const BOSS_ENEMY: MonsterData = preload("res://assets/data/monsters/hydra.tres")

const MOVE_POOL: Array[MoveData] = [
	preload("res://assets/data/moves/strike.tres"),
	preload("res://assets/data/moves/heavy.tres"),
	preload("res://assets/data/moves/slam.tres"),
	preload("res://assets/data/moves/guard.tres"),
	preload("res://assets/data/moves/mend.tres"),
	preload("res://assets/data/moves/drain.tres"),
	preload("res://assets/data/moves/focus.tres"),
]

const POWERUP_HP := 6      # +max HP a power-up grants when no new move can be learned
const ROOM_BONUS_HP := 5   # +max HP the treasure room grants party-wide

var _gs: Node
var _rng := RandomNumberGenerator.new()
var _map: Dictionary = {}
var _view = null                    # DungeonView (the walkable world)
var _active_battle: Battle = null
var _busy := false                  # a node is resolving (battle up, etc.)
var _ended := false                 # run won/lost; awaiting restart
var _wild_by_tier: Dictionary = {}  # tier:int -> Array[MonsterData]
var _max_tier := 0


func _ready() -> void:
	_rng.randomize()
	_build_wild_index()
	_gs = get_node_or_null("/root/RunState")
	if _gs == null:
		return   # headless / test context: no live run
	_show_title_screen()


func _show_title_screen() -> void:
	var title: TitleScreen = TITLE_SCREEN.new()
	title.started.connect(func():
		if _gs.has_living():
			_begin_run()
		else:
			_show_starter_select())
	add_child(title)


func _show_starter_select() -> void:
	var sel: StarterSelect = STARTER_SELECT.new()
	sel.setup(STARTER_ENEMIES)
	sel.chosen.connect(func(m):
		_gs.new_run(m)
		sel.queue_free()
		_begin_run())
	add_child(sel)


func _begin_run() -> void:
	_map = MAP_GENERATOR.new().generate(_rng)
	_ended = false
	_busy = false
	if _view != null:
		_view.queue_free()
	_view = DUNGEON_VIEW.new()
	_view.room_entered.connect(_enter_room)
	add_child(_view)
	_view.setup(_map)


## The player walked into an uncleared room — resolve that node.
func _enter_room(id: int) -> void:
	if _busy or _ended:
		return
	_busy = true
	var node: Dictionary = _map["nodes"][id]
	match node["type"]:
		"battle":
			_do_battle(id, _pick_wild(int(node["row"])))
		"elite":
			_do_battle(id, _pick_elite())
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
		"room":
			_grant_treasure()
			_advance(id)
		_:
			_advance(id)


func _do_battle(id: int, enemy: MonsterData) -> void:
	if not _gs.has_living():
		_game_over()
		return
	_view.set_walking(false)
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
				if enemy.is_elite:
					_heal_party()   # elite bonus: patch the party up after the tough fight
				_advance(id)
		Battle.Result.FLED:
			# Stay put in the (uncleared) room; step out and back to re-engage.
			_busy = false
			_view.set_walking(true)


## Clear a resolved room and hand movement back to the player.
func _advance(id: int) -> void:
	_view.clear_room(id)
	_busy = false
	_view.set_walking(true)


func _teleport(id: int) -> void:
	_view.clear_room(id)
	var target := _forward_two(id)
	if target >= 0:
		_view.warp_to(target)   # drop the player ~2 rows ahead to walk into that room
	_busy = false
	_view.set_walking(true)


## Follow uncleared forward edges ~2 rows ahead; -1 if there's nowhere to jump.
func _forward_two(id: int) -> int:
	var step1 := _uncleared(_map["nodes"][id]["to"])
	if step1.is_empty():
		return -1
	var n1: int = step1[_rng.randi_range(0, step1.size() - 1)]
	var step2 := _uncleared(_map["nodes"][n1]["to"])
	if step2.is_empty():
		return n1
	return step2[_rng.randi_range(0, step2.size() - 1)]


func _uncleared(ids: Array) -> Array:
	var out: Array = []
	for t in ids:
		if not _view.is_cleared(int(t)):
			out.append(int(t))
	return out


func _grant_treasure() -> void:
	for c in _gs.party:   # a small permanent +max HP to the whole party
		c.max_hp += ROOM_BONUS_HP
		c.hp += ROOM_BONUS_HP


func _heal_party() -> void:
	for c in _gs.party:
		c.hp = c.max_hp


func _apply_powerup() -> void:
	# Prefer teaching a random living monster a new move; if every monster already
	# knows every move, fall back to a small party-wide +max HP.
	var learners: Array = []
	for c in _gs.living():
		for mv in MOVE_POOL:
			if not _knows(c, mv):
				learners.append(c)
				break
	if learners.is_empty():
		for c in _gs.party:
			c.max_hp += POWERUP_HP
			c.hp += POWERUP_HP
		return
	var learner = learners[_rng.randi_range(0, learners.size() - 1)]
	var unknown: Array = []
	for mv in MOVE_POOL:
		if not _knows(learner, mv):
			unknown.append(mv)
	learner.moves.append(unknown[_rng.randi_range(0, unknown.size() - 1)])


func _knows(c, mv) -> bool:
	for m in c.moves:
		if m.id == mv.id:
			return true
	return false


## Group the wild pool by difficulty tier so encounters can scale with map depth.
func _build_wild_index() -> void:
	_wild_by_tier = {}
	_max_tier = 0
	for m in WILD_ENEMIES:
		_max_tier = maxi(_max_tier, m.tier)
		if not _wild_by_tier.has(m.tier):
			_wild_by_tier[m.tier] = []
		_wild_by_tier[m.tier].append(m)


## Pick a wild monster whose tier suits the node's depth: deeper rows draw tougher
## monsters, with a chance to draw one tier easier for variety.
func _pick_wild(row: int) -> MonsterData:
	var normal_rows: int = maxi(1, int(_map.get("rows", 7)) - 1)   # rows 0..normal_rows-1
	var band := clampi(int(row * (_max_tier + 1) / normal_rows), 0, _max_tier)
	if band > 0 and _rng.randf() < 0.35:
		band -= 1
	while band >= 0 and not _wild_by_tier.has(band):
		band -= 1
	var pool: Array = _wild_by_tier.get(maxi(band, 0), WILD_ENEMIES)
	return pool[_rng.randi_range(0, pool.size() - 1)]


func _pick_elite() -> MonsterData:
	return ELITE_ENEMIES[_rng.randi_range(0, ELITE_ENEMIES.size() - 1)]


func _win() -> void:
	if _view != null:
		_view.set_walking(false)
	_show_banner("YOU WIN!\nThe Hydra is vanquished.", Color(0.9, 0.75, 0.25))


func _game_over() -> void:
	if _view != null:
		_view.set_walking(false)
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
