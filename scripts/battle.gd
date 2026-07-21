class_name Battle
extends CanvasLayer
## Turn-based battle, run as a full-screen overlay added by the Overworld. The
## Overworld calls setup(enemy) then adds this to the tree; when the fight ends this
## emits `finished(result, enemy)` and the Overworld applies the consequences
## (award XP + clear the tile, game over, or nothing on a successful flee).
##
## Round flow: the player picks Attack / Defend / Flee, then the round resolves —
## attacks in speed order (player wins ties), Defend halves the incoming hit, Flee
## has a chance to end the fight (never against the boss).

enum Result { PLAYER_WON, PLAYER_LOST, FLED }
enum State { INTRO, PLAYER_COMMAND, RESOLVING, ENDED }

signal finished(result: int, enemy: EnemyData)

const STEP := 0.7   # seconds between battle messages (pacing)
const FLEE_CHANCE := 0.5

var _enemy_data: EnemyData
var _player: Combatant
var _enemy: Combatant
var _state: int = State.INTRO
var _rng := RandomNumberGenerator.new()
var _gs: Node   # the GameState autoload (looked up at runtime to avoid a compile-time dependency)

@onready var _enemy_name: Label = $Panel/Col/EnemyName
@onready var _enemy_hp: ProgressBar = $Panel/Col/EnemyHP
@onready var _enemy_sprite: ColorRect = $Panel/Col/EnemyArea/EnemySprite
@onready var _message: Label = $Panel/Col/Message
@onready var _btn_attack: Button = $Panel/Col/Actions/Attack
@onready var _btn_defend: Button = $Panel/Col/Actions/Defend
@onready var _btn_flee: Button = $Panel/Col/Actions/Flee
@onready var _player_name: Label = $Panel/Col/PlayerName
@onready var _player_hp: ProgressBar = $Panel/Col/PlayerHP


## Call before adding to the tree.
func setup(enemy_data: EnemyData) -> void:
	_enemy_data = enemy_data


func _ready() -> void:
	add_to_group("battle")
	_rng.randomize()
	_gs = get_node("/root/GameState")

	_player = Combatant.make(_gs.player_name, _gs.max_hp,
		_gs.attack, _gs.defense, _gs.speed)
	_player.hp = _gs.hp
	_enemy = Combatant.from_enemy(_enemy_data)
	_enemy_sprite.color = _enemy_data.tint

	_btn_attack.pressed.connect(_on_command.bind("attack"))
	_btn_defend.pressed.connect(_on_command.bind("defend"))
	_btn_flee.pressed.connect(_on_command.bind("flee"))

	_update_hud()
	_intro()


func _intro() -> void:
	_set_actions_enabled(false)
	var verb := "blocks your path!" if _enemy.is_boss else "appears!"
	await _say("%s %s" % [_enemy.display_name, verb])
	_begin_player_command()


func _begin_player_command() -> void:
	_state = State.PLAYER_COMMAND
	_player.defending = false
	_message.text = "What will you do?"
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
		await _enemy_act()
		if await _check_end(): return
		_begin_player_command()
		return

	if action == "defend":
		_player.defending = true
		await _say("You brace for the enemy's attack.")
		await _enemy_act()
		if await _check_end(): return
		_begin_player_command()
		return

	# action == "attack" — resolve both attacks in speed order.
	if _player.speed >= _enemy.speed:
		await _player_attack()
		if await _check_end(): return
		await _enemy_act()
	else:
		await _enemy_act()
		if await _check_end(): return
		await _player_attack()

	if await _check_end(): return
	_begin_player_command()


func _player_attack() -> void:
	var dmg := Combatant.compute_damage(_player, _enemy, _rng)
	_enemy.take_damage(dmg)
	_update_hud()
	await _say("You strike %s for %d damage!" % [_enemy.display_name, dmg])


func _enemy_act() -> void:
	if not _enemy.is_alive():
		return
	var dmg := Combatant.compute_damage(_enemy, _player, _rng)
	_player.take_damage(dmg)
	_update_hud()
	var blocked := "  (blocked)" if _player.defending else ""
	await _say("%s hits you for %d damage!%s" % [_enemy.display_name, dmg, blocked])


func _check_end() -> bool:
	if not _enemy.is_alive():
		await _say("%s is defeated!" % _enemy.display_name)
		_finish(Result.PLAYER_WON)
		return true
	if not _player.is_alive():
		await _say("You have fallen...")
		_finish(Result.PLAYER_LOST)
		return true
	return false


func _finish(result: int) -> void:
	_state = State.ENDED
	_set_actions_enabled(false)
	_gs.set_hp(_player.hp)   # persist remaining HP between fights
	finished.emit(result, _enemy_data)


func _update_hud() -> void:
	_enemy_name.text = "%s    HP %d/%d" % [_enemy.display_name, _enemy.hp, _enemy.max_hp]
	_enemy_hp.max_value = _enemy.max_hp
	_enemy_hp.value = _enemy.hp
	_player_name.text = "%s  Lv.%d    HP %d/%d" % [
		_gs.player_name, _gs.level, _player.hp, _player.max_hp]
	_player_hp.max_value = _player.max_hp
	_player_hp.value = _player.hp


func _say(text: String) -> void:
	_message.text = text
	await get_tree().create_timer(STEP).timeout


func _set_actions_enabled(on: bool) -> void:
	_btn_attack.disabled = not on
	_btn_defend.disabled = not on
	# No fleeing from the boss.
	_btn_flee.disabled = not on or (_enemy != null and _enemy.is_boss)
