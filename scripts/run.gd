extends Node
## The run controller — the game's main scene. Owns one roguelike run and renders it as a
## WALKABLE dungeon: generate a branching map, hand it to a DungeonView (rooms + corridors),
## and resolve a node when the player walks into its room. The whole dungeon is open and
## backtrackable, so you can reach every node if you like. Win the boss → YOU WIN; a party
## wipe → GAME OVER (press R for a fresh run). Nothing persists between runs.

const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")
const STARTER_SELECT := preload("res://scripts/starter_select.gd")
const POWERUP_SELECT := preload("res://scripts/powerup_select.gd")
const MERGE_SELECT := preload("res://scripts/merge_select.gd")
const POWERUP_REPO := preload("res://scripts/data/powerup_repo.gd")
const MOVE_REPO := preload("res://scripts/data/move_repo.gd")
const TITLE_SCREEN := preload("res://scripts/title_screen.gd")
const SETTINGS_MENU := preload("res://scripts/settings_menu.gd")
const DUNGEON_VIEW := preload("res://scripts/map/dungeon_view.gd")
const MAP_GENERATOR := preload("res://scripts/map/map_generator.gd")
const RUN_HISTORY := preload("res://scripts/data/run_history.gd")

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

const POWERUP_HP := 6      # +max HP the headless auto-power-up grants when no new move can be learned
const ROOM_BONUS_HP := 5   # +max HP the treasure room grants party-wide

# Interactive power-up chooser magnitudes (one is applied to the monster the player assigns).
const UPGRADE_HP := 10     # +max HP (and heals that much)
const UPGRADE_ATK := 3     # +attack
const UPGRADE_DEF := 3     # +defense

var _gs: Node
var _sound: Node   # the SoundManager autoload (looked up at runtime; may be null)
var _rng := RandomNumberGenerator.new()
var _map: Dictionary = {}
var _view = null                    # DungeonView (the walkable world)
var _active_battle: Battle = null
var _busy := false                  # a node is resolving (battle up, etc.)
var _ended := false                 # run won/lost; awaiting restart
var _settings_open := false         # the Settings overlay is up (Escape toggles it)
var _fade_layer: CanvasLayer = null # the in-progress fade-to-black overlay, if any
var _wild_by_tier: Dictionary = {}  # tier:int -> Array[MonsterData]
var _max_tier := 0

# Run tracking (scripts/data/run_history.gd) — recorded to user://run_history.json on win/loss.
# Dev-facing for now (balance reference); the same log could back an in-game history screen later.
var _starter_id := ""
var _nodes_resolved := 0
var _battles_fought := 0
var _died_to := ""       # the enemy's display name, if the run was lost to one
var _died_at_row := -1
var _recruited: Array[String] = []   # monster ids recruited this run, in order


func _ready() -> void:
	_rng.randomize()
	_build_wild_index()
	_gs = get_node_or_null("/root/RunState")
	if _gs == null:
		return   # headless / test context: no live run
	_sound = get_node_or_null("/root/SoundManager")
	_gs.party_changed.connect(_update_player_avatar)   # keep the map avatar on the lead monster
	_show_title_screen()


## Show the lead monster's art (with the player glow) as the dungeon avatar. Safe to call any
## time — no-ops when there's no live view or party yet; re-runs whenever the party changes.
func _update_player_avatar() -> void:
	if _view == null or _view.player == null or _gs.party.is_empty():
		return
	var lead: Combatant = _gs.party[0]
	if lead.source != null:
		_view.player.set_monster_appearance(lead.source)


func _show_title_screen() -> void:
	_music("title")
	var title: TitleScreen = TITLE_SCREEN.new()
	title.started.connect(_on_title_started)
	add_child(title)


## Fade to black, swap to the next screen underneath, then fade back in — so leaving the
## title screen isn't a hard cut. (title_screen.gd already frees itself synchronously on
## `started`; the fade overlay just covers that moment.)
func _on_title_started() -> void:
	await _fade_out()
	if _gs.has_living():
		_begin_run()
	else:
		_show_starter_select()
	await _fade_in()


func _show_starter_select() -> void:
	var sel: StarterSelect = STARTER_SELECT.new()
	sel.setup(STARTER_ENEMIES)
	sel.chosen.connect(func(m):
		_starter_id = String(m.id)
		_gs.new_run(m)
		sel.queue_free()
		_begin_run())
	add_child(sel)


func _begin_run() -> void:
	_music("dungeon")
	_map = MAP_GENERATOR.new().generate(_rng)
	_assign_encounters()
	_ended = false
	_busy = false
	if _view != null:
		_view.queue_free()
	_view = DUNGEON_VIEW.new()
	_view.room_entered.connect(_enter_room)
	add_child(_view)
	_view.setup(_map)
	_update_player_avatar()   # dress the spawned player as the lead monster


## Roll each battle/elite/boss node's monster up front (rather than on room-entry) so
## DungeonView can show a monster-specific map sprite on the marker when one exists
## (scripts/data/map_sprites.gd), and so re-entering a fled fight shows the same monster.
func _assign_encounters() -> void:
	for n in _map["nodes"]:
		match n["type"]:
			"battle":
				n["enemy"] = _pick_wild(int(n["row"]))
			"elite":
				n["enemy"] = _pick_elite()
			"boss":
				n["enemy"] = BOSS_ENEMY


## The player walked into an uncleared room — resolve that node.
func _enter_room(id: int) -> void:
	if _busy or _ended:
		return
	_busy = true
	_nodes_resolved += 1
	var node: Dictionary = _map["nodes"][id]
	match node["type"]:
		"battle", "elite", "boss":
			_do_battle(id, node["enemy"])
		"heal":
			_sfx("node_heal")
			_heal_party()
			_advance(id)
		"powerup":
			_sfx("node_powerup")
			_open_powerup_chooser(id)
		"teleport":
			_sfx("node_teleport")
			_teleport(id)
		"room":
			_sfx("node_room")
			_grant_treasure()
			_advance(id)
		_:
			_advance(id)


func _do_battle(id: int, enemy: MonsterData) -> void:
	if not _gs.has_living():
		_game_over()
		return
	_battles_fought += 1
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
			_died_to = enemy.display_name
			_died_at_row = int(_map["nodes"][id]["row"])
			_game_over()
		Battle.Result.PLAYER_WON:
			if enemy.is_boss:
				_win()
			elif _gs.is_full():
				# Party's full — offer a merge to make room (or skip the recruit).
				_open_merge_prompt(id, enemy)
			else:
				if _gs.add_monster(enemy):
					_recruited.append(String(enemy.id))
				if enemy.is_elite:
					_heal_party()   # elite bonus: patch the party up after the tough fight
				_advance(id)
		Battle.Result.FLED:
			# Stay put in the (uncleared) room; step out and back to re-engage.
			_busy = false
			_view.set_walking(true)


## Party-full recruit: pop the merge overlay. On Merge, fuse the two picks (freeing a slot) and
## recruit the new monster; on Skip, keep the party as-is and don't recruit. Either way the elite
## heal (if any) still applies, then the room clears. Headless-safe: with no live view it just
## skips the recruit, matching the pre-merge behavior.
func _open_merge_prompt(id: int, enemy: MonsterData) -> void:
	if _view == null:
		if enemy.is_elite:
			_heal_party()
		_advance(id)
		return
	_view.set_walking(false)
	var sel: MergeSelect = MERGE_SELECT.new()
	sel.setup(_gs.living(), enemy)
	sel.merged.connect(func(a, b):
		_gs.merge(a, b)
		if _gs.add_monster(enemy):
			_recruited.append(String(enemy.id))
		if enemy.is_elite:
			_heal_party()
		sel.queue_free()
		_advance(id))
	sel.skipped.connect(func():
		if enemy.is_elite:
			_heal_party()
		sel.queue_free()
		_advance(id))
	add_child(sel)


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


## Interactive power-up: pop the chooser overlay (3 upgrades → assign to a monster), apply the
## pick, then clear the room. Falls back to the headless auto-power-up if there's no live view
## (shouldn't happen in the real game — room_entered only fires with a view).
func _open_powerup_chooser(id: int) -> void:
	if _view == null:
		_apply_powerup()
		_advance(id)
		return
	_view.set_walking(false)
	var sel: PowerupSelect = POWERUP_SELECT.new()
	sel.setup(_build_upgrade_options(), _gs.living())
	sel.chosen.connect(func(up, monster):
		_grant_upgrade(monster, up)
		sel.queue_free()
		_advance(id))
	add_child(sel)


## Build the (up to) 3 upgrade choices offered by the chooser, drawn from the DATA-DRIVEN power-up
## roster (assets/data/powerups/*.tres, editable via the power-up editor dock). Offers a learnable
## move when one exists plus stat buffs to fill three slots — a mix of "hp/attack/defense or new
## moves". Each choice is a Dictionary the overlay renders and _grant_upgrade() applies; a "move"
## power-up whose move nobody can learn (or whose move is missing) is skipped. Falls back to the
## built-in stat buffs if no power-up data is authored, so a run never breaks.
func _build_upgrade_options() -> Array:
	var pool := POWERUP_REPO.load_all()
	if pool.is_empty():
		return _fallback_stat_options()
	var moves: Array = []
	var stats: Array = []
	for p in pool:
		var opt := _powerup_to_option(p)
		if opt.is_empty():
			continue
		if String(opt["type"]) == "move":
			moves.append(opt)
		else:
			stats.append(opt)
	_shuffle(moves)
	_shuffle(stats)
	var out: Array = []
	if not moves.is_empty():
		out.append(moves[0])          # always offer a learnable move when one's available
	for s in stats:                    # fill the rest with stat buffs
		if out.size() >= 3:
			break
		out.append(s)
	for m in moves.slice(1):           # top up from remaining moves (e.g. an all-move roster)
		if out.size() >= 3:
			break
		out.append(m)
	if out.is_empty():
		return _fallback_stat_options()
	return out


## Convert a PowerupData into the option Dictionary the chooser/`_grant_upgrade` use, or {} when
## it can't be offered (a "move" power-up whose move is missing or already known by everyone).
func _powerup_to_option(p) -> Dictionary:
	var opt := {
		"id": String(p.id), "type": String(p.effect), "amount": int(p.amount),
		"move": null, "label": String(p.display_name), "desc": String(p.description),
		"tint": p.tint,
	}
	if String(p.effect) == "move":
		var mv = MOVE_REPO.load_one(String(p.move_id))
		if mv == null:
			return {}
		var learnable := false
		for c in _gs.living():
			if not _knows(c, mv):
				learnable = true
				break
		if not learnable:
			return {}
		opt["move"] = mv
	return opt


## The built-in stat buffs — used only when no power-up data exists on disk (so a run is safe even
## with an empty assets/data/powerups/).
func _fallback_stat_options() -> Array:
	var stats: Array = [
		{"id": "", "type": "hp", "amount": UPGRADE_HP, "move": null,
			"label": "+%d Max HP" % UPGRADE_HP, "desc": "Raise & heal", "tint": Color(0.85, 0.22, 0.28)},
		{"id": "", "type": "attack", "amount": UPGRADE_ATK, "move": null,
			"label": "+%d Attack" % UPGRADE_ATK, "desc": "Hit harder", "tint": Color(0.92, 0.55, 0.18)},
		{"id": "", "type": "defense", "amount": UPGRADE_DEF, "move": null,
			"label": "+%d Defense" % UPGRADE_DEF, "desc": "Take less", "tint": Color(0.26, 0.5, 0.9)},
	]
	_shuffle(stats)
	return stats.slice(0, 3)


## Apply one upgrade Dictionary to a specific monster (the recipient the player assigned).
func _grant_upgrade(monster, up: Dictionary) -> void:
	match String(up["type"]):
		"hp":
			monster.max_hp += int(up["amount"])
			monster.hp += int(up["amount"])
		"attack":
			monster.attack += int(up["amount"])
		"defense":
			monster.defense += int(up["amount"])
		"move":
			if not _knows(monster, up["move"]):
				monster.moves.append(up["move"])


## In-place Fisher-Yates shuffle using the run's seeded RNG (Array.shuffle() uses the global one).
func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


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
	_sfx("win")
	RUN_HISTORY.record(_build_run_record("won"))
	if _view != null:
		_view.set_walking(false)
	_show_banner("YOU WIN!\nThe Hydra is vanquished.", Color(0.9, 0.75, 0.25))


func _game_over() -> void:
	_sfx("lose")
	RUN_HISTORY.record(_build_run_record("lost"))
	if _view != null:
		_view.set_walking(false)
	_show_banner("GAME OVER\nPress R for a new run.", Color(0.85, 0.28, 0.28))


## See scripts/data/run_history.gd for the record shape convention.
func _build_run_record(outcome: String) -> Dictionary:
	var final_party: Array = []
	for c in _gs.party:
		final_party.append({
			"id": String(c.source.id) if c.source != null else "",
			"display_name": c.display_name,
			"hp": c.hp,
			"max_hp": c.max_hp,
		})
	return {
		"starter_id": _starter_id,
		"outcome": outcome,
		"nodes_resolved": _nodes_resolved,
		"battles_fought": _battles_fought,
		"died_to": _died_to,
		"died_at_row": _died_at_row,
		"recruited": _recruited,
		"final_party": final_party,
	}


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


func _sfx(id: String) -> void:
	if _sound != null:
		_sound.play_sfx(id)


func _music(id: String) -> void:
	if _sound != null:
		_sound.play_music(id)


const FADE_TIME := 0.25

## Cover the screen in black. Await this before swapping content so the swap is hidden.
func _fade_out() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60   # above every other overlay (Settings 45, DebugOverlay 50 included)
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 0)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP   # block input while covered
	layer.add_child(rect)
	add_child(layer)
	_fade_layer = layer
	var tw := create_tween()
	tw.tween_property(rect, "color:a", 1.0, FADE_TIME)
	await tw.finished


## Reveal whatever was swapped in underneath, then drop the fade overlay.
func _fade_in() -> void:
	if _fade_layer == null:
		return
	var rect: ColorRect = _fade_layer.get_child(0)
	var tw := create_tween()
	tw.tween_property(rect, "color:a", 0.0, FADE_TIME)
	await tw.finished
	_fade_layer.queue_free()
	_fade_layer = null


## Escape opens Settings from any screen (title, starter select, dungeon, battle). Guarded so a
## second Escape while it's already open is a no-op here — SettingsMenu closes itself on Escape.
func _open_settings() -> void:
	_settings_open = true
	if _view != null:
		_view.set_walking(false)
	var menu: SettingsMenu = SETTINGS_MENU.new()
	menu.closed.connect(func():
		_settings_open = false
		if _view != null and not _busy:
			_view.set_walking(true))
	add_child(menu)


func _unhandled_input(event: InputEvent) -> void:
	if _ended and event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_R:
		if _gs != null:
			_gs.new_run(null)   # clear the party; _ready will prompt for a new starter
		get_tree().reload_current_scene()
	if not _settings_open and event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		_open_settings()
