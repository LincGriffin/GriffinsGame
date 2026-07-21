class_name Battle
extends CanvasLayer
## Turn-based battle, run as a full-screen overlay added by the Overworld. Your side
## fields ONE active monster at a time, drawn from RunState's party; you pick which
## one leads, and when it falls you switch in another. A downed monster is permadead
## for the run. You lose only when the whole party is wiped.
##
## The Overworld calls setup(enemy) then adds this to the tree; when the fight ends
## this emits `finished(result, enemy)` and the Overworld applies the consequences
## (recruit the defeated monster + clear the tile, game over, or nothing on a flee).
## HP persists automatically: the party Combatants are shared with RunState.

enum Result { PLAYER_WON, PLAYER_LOST, FLED }
enum State { INTRO, CHOOSE_LEAD, PLAYER_COMMAND, RESOLVING, SWITCHING, ENDED }

signal finished(result: int, enemy: MonsterData)
signal _choice_made(monster: Combatant)   # internal: a monster-select button was pressed

const STEP := 0.7   # seconds between battle messages (pacing)
const FLEE_CHANCE := 0.5

var _enemy_data: MonsterData
var _party: Array = []        # Array[Combatant] — the run's monsters (shared with RunState)
var _active: Combatant = null # the monster currently fighting
var _enemy: Combatant
var _state: int = State.INTRO
var _rng := RandomNumberGenerator.new()
var _gs: Node                 # the RunState autoload (looked up at runtime)
var _dynamic_buttons: Array = []   # monster-select buttons created on the fly

@onready var _enemy_name: Label = $Panel/Col/EnemyName
@onready var _enemy_hp: ProgressBar = $Panel/Col/EnemyHP
@onready var _enemy_sprite: ColorRect = $Panel/Col/EnemyArea/EnemySprite
@onready var _message: Label = $Panel/Col/Message
@onready var _actions: HBoxContainer = $Panel/Col/Actions
@onready var _btn_attack: Button = $Panel/Col/Actions/Attack
@onready var _btn_defend: Button = $Panel/Col/Actions/Defend
@onready var _btn_flee: Button = $Panel/Col/Actions/Flee
@onready var _player_name: Label = $Panel/Col/PlayerName
@onready var _player_hp: ProgressBar = $Panel/Col/PlayerHP


## Call before adding to the tree.
func setup(enemy_data: MonsterData) -> void:
	_enemy_data = enemy_data


func _ready() -> void:
	add_to_group("battle")
	_rng.randomize()
	_gs = get_node("/root/RunState")

	_enemy = Combatant.from_monster(_enemy_data)
	_enemy_sprite.color = _enemy_data.tint
	_party = _gs.living()   # shared Combatant refs → damage persists between fights

	_btn_attack.pressed.connect(_on_command.bind("attack"))
	_btn_defend.pressed.connect(_on_command.bind("defend"))
	_btn_flee.pressed.connect(_on_command.bind("flee"))

	_update_hud()
	_intro()


func _intro() -> void:
	_set_actions_enabled(false)
	var verb := "blocks your path!" if _enemy.is_boss else "appears!"
	await _say("%s %s" % [_enemy.display_name, verb])
	await _choose_lead()


## Pick the monster that starts the battle (skipped automatically with only one).
func _choose_lead() -> void:
	var options := _living_party()
	if options.size() <= 1:
		_set_active(options[0])
	else:
		_state = State.CHOOSE_LEAD
		_set_static_actions_visible(false)
		_message.text = "Choose your lead monster!"
		var chosen: Combatant = await _prompt_monster(options)
		_set_active(chosen)
	_begin_player_command()


func _begin_player_command() -> void:
	_state = State.PLAYER_COMMAND
	_active.defending = false
	_set_static_actions_visible(true)
	_message.text = "What will %s do?" % _active.display_name
	_set_actions_enabled(true)


func _on_command(action: String) -> void:
	if _state != State.PLAYER_COMMAND:
		return
	_state = State.RESOLVING
	_set_actions_enabled(false)
	await _resolve_round(action)


func _resolve_round(action: String) -> void:
	if action == "flee":
		if _enemy.is_boss:
			await _say("There is no escaping the boss!")
		elif _rng.randf() < FLEE_CHANCE:
			await _say("You got away safely!")
			_finish(Result.FLED)
			return
		else:
			await _say("You couldn't escape!")
		await _enemy_turn()
		if _state == State.ENDED: return
		_begin_player_command()
		return

	if action == "defend":
		_active.defending = true
		await _say("%s braces for the attack." % _active.display_name)
		await _enemy_turn()
		if _state == State.ENDED: return
		_begin_player_command()
		return

	# action == "attack" — resolve both attacks in speed order (player wins ties).
	if _active.speed >= _enemy.speed:
		await _player_attack()
		if await _check_enemy_down(): return
		await _enemy_turn()
		if _state == State.ENDED: return
	else:
		await _enemy_turn()
		if _state == State.ENDED: return
		await _player_attack()
		if await _check_enemy_down(): return

	_begin_player_command()


func _player_attack() -> void:
	var dmg := Combatant.compute_damage(_active, _enemy, _rng)
	_enemy.take_damage(dmg)
	_update_hud()
	await _say("%s strikes %s for %d!" % [_active.display_name, _enemy.display_name, dmg])


## Enemy attacks the active monster; if that monster falls, force a switch (or lose).
func _enemy_turn() -> void:
	if not _enemy.is_alive():
		return
	var dmg := Combatant.compute_damage(_enemy, _active, _rng)
	_active.take_damage(dmg)
	_update_hud()
	var blocked := "  (blocked)" if _active.defending else ""
	await _say("%s hits %s for %d!%s" % [_enemy.display_name, _active.display_name, dmg, blocked])
	if not _active.is_alive():
		await _on_active_defeated()


func _check_enemy_down() -> bool:
	if _enemy.is_alive():
		return false
	await _say("%s is defeated!" % _enemy.display_name)
	_finish(Result.PLAYER_WON)
	return true


func _on_active_defeated() -> void:
	await _say("%s is down!" % _active.display_name)
	var options := _living_party()   # the downed monster (hp 0) is already excluded
	if options.is_empty():
		await _say("Your whole party has fallen...")
		_finish(Result.PLAYER_LOST)
		return
	_state = State.SWITCHING
	_set_static_actions_visible(false)
	var next: Combatant
	if options.size() == 1:
		next = options[0]
		await _say("%s steps up!" % next.display_name)
	else:
		_message.text = "Choose your next monster!"
		next = await _prompt_monster(options)
	_set_active(next)
	# The enemy already acted this round; _resolve_round hands control back.


func _finish(result: int) -> void:
	_state = State.ENDED
	_set_actions_enabled(false)
	_clear_dynamic_buttons()
	finished.emit(result, _enemy_data)   # HP already lives on the shared party Combatants


func _set_active(c: Combatant) -> void:
	_active = c
	_active.defending = false
	_update_hud()


func _living_party() -> Array:
	return _party.filter(func(c): return c.is_alive())


## Build one button per option, wait for a press, then tear the buttons down.
func _prompt_monster(options: Array) -> Combatant:
	_clear_dynamic_buttons()
	for c in options:
		var b := Button.new()
		b.text = "%s  (%d/%d)" % [c.display_name, c.hp, c.max_hp]
		b.custom_minimum_size = Vector2(160, 40)
		b.pressed.connect(func(): _choice_made.emit(c))
		_actions.add_child(b)
		_dynamic_buttons.append(b)
	var chosen: Combatant = await _choice_made
	_clear_dynamic_buttons()
	return chosen


func _clear_dynamic_buttons() -> void:
	for b in _dynamic_buttons:
		b.queue_free()
	_dynamic_buttons.clear()


func _update_hud() -> void:
	_enemy_name.text = "%s    HP %d/%d" % [_enemy.display_name, _enemy.hp, _enemy.max_hp]
	_enemy_hp.max_value = _enemy.max_hp
	_enemy_hp.value = _enemy.hp
	if _active != null:
		_player_name.text = "%s    HP %d/%d    (party %d)" % [
			_active.display_name, _active.hp, _active.max_hp, _living_party().size()]
		_player_hp.max_value = _active.max_hp
		_player_hp.value = _active.hp
	else:
		_player_name.text = "Party: %d monster(s)" % _living_party().size()
		_player_hp.value = 0


func _say(text: String) -> void:
	_message.text = text
	await get_tree().create_timer(STEP).timeout


func _set_actions_enabled(on: bool) -> void:
	_btn_attack.disabled = not on
	_btn_defend.disabled = not on
	# No fleeing from the boss.
	_btn_flee.disabled = not on or (_enemy != null and _enemy.is_boss)


func _set_static_actions_visible(v: bool) -> void:
	_btn_attack.visible = v
	_btn_defend.visible = v
	_btn_flee.visible = v
