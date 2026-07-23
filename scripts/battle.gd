class_name Battle
extends CanvasLayer
## Turn-based battle, run as a full-screen overlay added by the Run controller. Your
## side fields ONE active monster at a time, drawn from RunState's party; you pick which
## one leads, and when it falls you switch in another. A downed monster is permadead for
## the run. You lose only when the whole party is wiped.
##
## The command menu lists the active monster's MOVES (plus Flee vs non-boss). Move kinds:
## attack (damage = attack + power - def/2), drain (attack that heals half the damage dealt),
## guard (halve the incoming hit), evade (the next hit deals 0 damage), reflect (the next hit is
## redirected to its attacker instead), heal (restore HP), buff (raise attack for the battle),
## stun (an attack that also skips the target's next turn), and reckless (a heavy attack that
## also damages its own user). HP persists automatically — the party Combatants are shared with
## RunState.

enum Result { PLAYER_WON, PLAYER_LOST, FLED }
enum State { INTRO, CHOOSE_LEAD, PLAYER_COMMAND, RESOLVING, SWITCHING, ENDED }

signal finished(result: int, enemy: MonsterData)
signal _choice_made(monster: Combatant)   # internal: a monster-select button was pressed
## Synchronization points for driving a battle programmatically (BattleHarness) instead of
## clicking through the UI — purely additive, nothing in normal play listens to these.
signal command_ready                      # the command menu is up; _actions has live buttons
signal monster_prompt_ready(options: Array)  # a monster-select prompt is up, awaiting a choice

var STEP := 0.7   # seconds between battle messages (pacing) — a var (not const) so a test
                   # harness can drop it to ~0 before add_child(); default matches normal play.
const FLEE_CHANCE := 0.5
const FLEE_ENABLED := false   # hidden for now — flip back on to restore the Flee command

# HP bar juice: animated fill + a green/yellow/red tint by remaining percentage.
const HP_TWEEN_TIME := 0.35
const HP_HIGH_COLOR := Color(0.35, 0.85, 0.35)
const HP_MID_COLOR := Color(0.90, 0.80, 0.25)
const HP_LOW_COLOR := Color(0.85, 0.25, 0.25)

# Floating damage/heal numbers.
const DMG_COLOR := Color(1.0, 0.35, 0.35)
const HEAL_COLOR := Color(0.4, 1.0, 0.5)
const POPUP_RISE := 42.0
const POPUP_TIME := 0.7

# Hit feedback: a brief brighten-flash + position-jitter shake.
const FLASH_COLOR := Color(2.2, 2.2, 2.2)
const SHAKE_STRENGTH := 6.0

## Preloaded rather than referenced by class_name so this compiles regardless of whether the
## global class cache has been rebuilt yet (same reason the generators use load()).
const PORTRAITS := preload("res://scripts/data/portraits.gd")
const BUTTON_POLISH := preload("res://scripts/button_polish.gd")

var _enemy_data: MonsterData
var _party: Array = []        # Array[Combatant] — the run's monsters (shared with RunState)
var _active: Combatant = null # the monster currently fighting
var _enemy: Combatant
var _state: int = State.INTRO
var _rng := RandomNumberGenerator.new()
var _gs: Node                 # the RunState autoload (looked up at runtime)
var _sound: Node              # the SoundManager autoload (looked up at runtime; may be null)
var _dynamic_buttons: Array = []   # command / monster-select buttons created on the fly
var _hp_tweens: Dictionary = {}    # ProgressBar -> Tween (killed/replaced on each HUD update)
var _hp_styles: Dictionary = {}    # ProgressBar -> its own StyleBoxFlat "fill" override

@onready var _enemy_name: Label = $Panel/Col/EnemyName
@onready var _enemy_hp: ProgressBar = $Panel/Col/EnemyHP
@onready var _enemy_sprite: ColorRect = $Panel/Col/EnemyArea/EnemySprite
@onready var _enemy_portrait: TextureRect = $Panel/Col/EnemyArea/EnemySprite/Portrait
@onready var _message: Label = $Panel/Col/Message
@onready var _actions: HBoxContainer = $Panel/Col/Actions
@onready var _player_name: Label = $Panel/Col/PlayerName
@onready var _player_hp: ProgressBar = $Panel/Col/PlayerHP


## Call before adding to the tree.
func setup(enemy_data: MonsterData) -> void:
	_enemy_data = enemy_data


func _ready() -> void:
	add_to_group("battle")
	_rng.randomize()
	_gs = get_node("/root/RunState")
	_sound = get_node_or_null("/root/SoundManager")
	_music("battle_boss" if _enemy_data.is_boss else "battle")

	_enemy = Combatant.from_monster(_enemy_data)
	# Portrait art covers the tint block when this monster has some; otherwise the flat
	# tint block stands in, so a missing portrait is never a broken screen.
	_enemy_sprite.color = _enemy_data.tint
	var art := PORTRAITS.for_monster(_enemy_data)
	_enemy_portrait.texture = art
	_enemy_portrait.visible = art != null
	_party = _gs.living()   # shared Combatant refs → damage persists between fights

	# The scene ships with placeholder Attack/Defend/Flee buttons; the command menu is
	# built dynamically from the active monster's moves instead.
	for c in _actions.get_children():
		_actions.remove_child(c)
		c.queue_free()

	_update_hud()
	_intro()


func _intro() -> void:
	_sfx("encounter_boss" if _enemy.is_boss else "encounter")
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
		_message.text = "Choose your lead monster!"
		var chosen: Combatant = await _prompt_monster(options)
		_set_active(chosen)
	await _begin_player_command()


func _begin_player_command() -> void:
	if _active.stunned:
		_active.stunned = false
		await _say("%s is stunned and can't move!" % _active.display_name)
		await _end_player_turn()
		return
	_state = State.PLAYER_COMMAND
	_active.defending = false
	_active.evading = false
	_active.reflecting = false
	_message.text = "What will %s do?" % _active.display_name
	_build_command_buttons()
	command_ready.emit()


## After a move that doesn't itself fight (guard/heal/buff/reflect/evade/switch/failed-flee/
## stunned-skip), hand the turn to the enemy and either continue or end the battle. The extra
## _check_enemy_down() covers a reflected hit killing the enemy on the enemy's own turn — a
## no-op for every other (never self-damaging) enemy turn.
func _end_player_turn() -> void:
	await _enemy_turn()
	if _state == State.ENDED: return
	if await _check_enemy_down(): return
	await _begin_player_command()


## One button per move on the active monster, plus Switch (if another monster can take over)
## and Flee (hidden for now — see FLEE_ENABLED; never shown against the boss anyway).
func _build_command_buttons() -> void:
	_clear_dynamic_buttons()
	for mv in _active.moves:
		_add_button(mv.display_name, _on_move.bind(mv))
	if _living_party().size() > 1:
		_add_button("Switch", _on_switch)
	if FLEE_ENABLED and not _enemy.is_boss:
		_add_button("Flee", _on_flee)


func _on_move(mv) -> void:
	if _state != State.PLAYER_COMMAND:
		return
	_state = State.RESOLVING
	_clear_dynamic_buttons()
	await _resolve_move(mv)


## Voluntarily switch the active monster out before it faints — costs the turn (the enemy still
## acts), same as guard/heal/buff. Cancel returns to the command menu with no turn spent.
func _on_switch() -> void:
	if _state != State.PLAYER_COMMAND:
		return
	var options := _living_party().filter(func(c): return c != _active)
	if options.is_empty():
		return
	_state = State.RESOLVING
	_clear_dynamic_buttons()
	_message.text = "Switch to which monster?"
	var next: Combatant = await _prompt_monster(options, true)
	if next == null:
		await _begin_player_command()   # cancelled — no turn spent
		return
	_sfx("switch")
	_set_active(next)
	await _say("%s steps in!" % next.display_name)
	await _end_player_turn()


func _on_flee() -> void:
	if _state != State.PLAYER_COMMAND:
		return
	_state = State.RESOLVING
	_clear_dynamic_buttons()
	if _rng.randf() < FLEE_CHANCE:
		_sfx("flee")
		await _say("You got away safely!")
		_finish(Result.FLED)
		return
	await _say("You couldn't escape!")
	await _end_player_turn()


func _resolve_move(mv) -> void:
	match mv.kind:
		"guard":
			_sfx("move_guard")
			_active.defending = true
			await _say("%s guards." % _active.display_name)
			await _end_player_turn()
		"evade":
			_sfx("move_evade")
			_active.evading = true
			await _say("%s prepares to evade!" % _active.display_name)
			await _end_player_turn()
		"reflect":
			_sfx("move_reflect")
			_active.reflecting = true
			await _say("%s readies a reflect!" % _active.display_name)
			await _end_player_turn()
		"heal":
			_sfx("move_heal")
			var before := _active.hp
			_active.hp = mini(_active.hp + mv.power, _active.max_hp)
			_update_hud()
			var healed := _active.hp - before
			if healed > 0:
				_pop_number(_player_hp, "+%d" % healed, HEAL_COLOR)
			await _say("%s mends %d HP." % [_active.display_name, healed])
			await _end_player_turn()
		"buff":
			_sfx("move_buff")
			_active.atk_bonus += mv.power
			_update_hud()
			await _say("%s uses %s — attack rose!" % [_active.display_name, mv.display_name])
			await _end_player_turn()
		_:   # attack / drain / stun / reckless — resolve both sides in speed order (player wins ties)
			if _active.speed >= _enemy.speed:
				await _player_attack(mv)
				if await _check_enemy_down(): return
				await _enemy_turn()
				if _state == State.ENDED: return
				if await _check_enemy_down(): return
			else:
				await _enemy_turn()
				if _state == State.ENDED: return
				if await _check_enemy_down(): return
				await _player_attack(mv)
				if await _check_enemy_down(): return
			await _begin_player_command()


## Resolves one damage-dealing hit from `attacker` against `target`, honoring the target's
## evade/reflect stance (both one-shot — consumed here regardless of the outcome). Applies the
## damage to whichever combatant actually takes it (the target normally, or the attacker when
## reflected) and returns a summary the caller uses for messaging/feedback. Evaded and reflected
## hits skip every secondary effect (drain heal / stun / reckless recoil) — the move's only
## remaining effect is the 0 damage / redirected damage itself.
func _resolve_hit(attacker: Combatant, target: Combatant, move_power: int) -> Dictionary:
	if target.evading:
		target.evading = false
		return {"dmg": 0, "evaded": true, "reflected": false}
	var dmg: int = Combatant.compute_damage(attacker, target, _rng, move_power)
	if target.reflecting:
		target.reflecting = false
		attacker.take_damage(dmg)
		return {"dmg": dmg, "evaded": false, "reflected": true}
	target.take_damage(dmg)
	return {"dmg": dmg, "evaded": false, "reflected": false}


## Applies a LANDED hit's secondary effects (drain heal / stun / reckless recoil) — never called
## for an evaded or reflected hit — and returns a message suffix describing them.
## `attacker_anchor` is where recoil/drain-heal popups land (the attacker's own HP bar/sprite).
func _apply_secondary_effects(mv, attacker: Combatant, target: Combatant, dmg: int,
		attacker_anchor: Control) -> String:
	match mv.kind:
		"drain":
			var before := attacker.hp
			attacker.hp = mini(attacker.hp + int(floor(dmg / 2.0)), attacker.max_hp)
			var healed := attacker.hp - before
			if healed <= 0:
				return ""
			_pop_number(attacker_anchor, "+%d" % healed, HEAL_COLOR)
			return "  (+%d HP)" % healed
		"stun":
			target.stunned = true
			return "  %s is stunned!" % target.display_name
		"reckless":
			var recoil: int = maxi(1, int(floor(dmg / 4.0)))
			attacker.take_damage(recoil)
			_pop_number(attacker_anchor, "-%d" % recoil, DMG_COLOR)
			return "  %s is hurt by recoil (%d)!" % [attacker.display_name, recoil]
	return ""


func _player_attack(mv) -> void:
	_sfx("move_" + mv.kind)
	var result := _resolve_hit(_active, _enemy, mv.power)
	var dmg: int = result["dmg"]
	if result["evaded"]:
		_update_hud()
		await _say("%s uses %s — %s evades the attack!" %
			[_active.display_name, mv.display_name, _enemy.display_name])
		return
	if result["reflected"]:
		_hit_feedback(_player_hp)
		_pop_number(_player_hp, "-%d" % dmg, DMG_COLOR)
		_update_hud()
		await _say("%s reflects %s's %s back — %d damage!" %
			[_enemy.display_name, _active.display_name, mv.display_name, dmg])
		return
	_hit_feedback(_enemy_sprite)
	_pop_number(_enemy_sprite, "-%d" % dmg, DMG_COLOR)
	var extra := _apply_secondary_effects(mv, _active, _enemy, dmg, _player_hp)
	_update_hud()
	await _say("%s uses %s — %d damage!%s" % [_active.display_name, mv.display_name, dmg, extra])


## Enemy attacks the active monster with a random one of its offensive moves (attack / drain /
## stun / reckless); if that monster falls, force a switch (or lose). Skips entirely if stunned.
func _enemy_turn() -> void:
	if not _enemy.is_alive():
		return
	if _enemy.stunned:
		_enemy.stunned = false
		await _say("%s is stunned and can't move!" % _enemy.display_name)
		return
	var mv = _enemy_pick_move()
	var power: int = mv.power if mv != null else 0
	var result := _resolve_hit(_enemy, _active, power)
	var dmg: int = result["dmg"]
	_sfx("enemy_hit")
	if result["evaded"]:
		_update_hud()
		await _say("%s attacks — %s evades!" % [_enemy.display_name, _active.display_name])
		return
	if result["reflected"]:
		_hit_feedback(_enemy_sprite)
		_pop_number(_enemy_sprite, "-%d" % dmg, DMG_COLOR)
		_update_hud()
		await _say("%s reflects the attack back at %s — %d damage!" %
			[_active.display_name, _enemy.display_name, dmg])
		return
	_shake(_player_hp)
	_pop_number(_player_hp, "-%d" % dmg, DMG_COLOR)
	var extra := _apply_secondary_effects(mv, _enemy, _active, dmg, _enemy_sprite) if mv != null else ""
	_update_hud()
	var blocked := "  (blocked)" if _active.defending else ""
	await _say("%s hits %s for %d!%s%s" % [_enemy.display_name, _active.display_name, dmg, blocked, extra])
	if not _active.is_alive():
		await _on_active_defeated()


## The enemy's offensive moves (attack / drain / stun / reckless); null if it somehow has none.
func _enemy_pick_move():
	var usable := _enemy.moves.filter(func(m): return m.kind in ["attack", "drain", "stun", "reckless"])
	if usable.is_empty():
		return null
	return usable[_rng.randi_range(0, usable.size() - 1)]


func _check_enemy_down() -> bool:
	if _enemy.is_alive():
		return false
	_sfx("victory")
	await _say("%s is defeated!" % _enemy.display_name)
	_finish(Result.PLAYER_WON)
	return true


func _on_active_defeated() -> void:
	_sfx("faint")
	await _say("%s is down!" % _active.display_name)
	var options := _living_party()   # the downed monster (hp 0) is already excluded
	if options.is_empty():
		_sfx("defeat")
		await _say("Your whole party has fallen...")
		_finish(Result.PLAYER_LOST)
		return
	_state = State.SWITCHING
	var next: Combatant
	if options.size() == 1:
		next = options[0]
		await _say("%s steps up!" % next.display_name)
	else:
		_message.text = "Choose your next monster!"
		next = await _prompt_monster(options)
	_set_active(next)
	# The enemy already acted this round; _resolve_move hands control back.


func _finish(result: int) -> void:
	_state = State.ENDED
	_clear_dynamic_buttons()
	finished.emit(result, _enemy_data)   # HP already lives on the shared party Combatants


func _set_active(c: Combatant) -> void:
	_active = c
	_active.defending = false
	_active.evading = false
	_active.reflecting = false
	_active.atk_bonus = 0   # buffs never carry between battles or across a switch
	_update_hud()


func _living_party() -> Array:
	return _party.filter(func(c): return c.is_alive())


## Add a command button. Monster-select buttons pass their portrait as `icon` so you can
## see who you're sending in; move buttons pass none.
func _add_button(text: String, cb: Callable, icon: Texture2D = null) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(130, 40) if icon == null else Vector2(176, 84)
	b.focus_mode = Control.FOCUS_NONE
	if icon != null:
		b.icon = icon
		b.expand_icon = true   # scale the 256px portrait down into the button
	BUTTON_POLISH.apply(b)
	b.pressed.connect(cb)
	_actions.add_child(b)
	_dynamic_buttons.append(b)


## Build one button per monster option, wait for a press, then tear the buttons down. With
## `allow_cancel`, an extra Cancel button resolves to null (used by a voluntary switch, where
## backing out shouldn't cost the turn; the forced switch-on-faint prompt never allows this).
func _prompt_monster(options: Array, allow_cancel: bool = false) -> Combatant:
	_clear_dynamic_buttons()
	for c in options:
		_add_button("%s  (%d/%d)" % [c.display_name, c.hp, c.max_hp],
			func(): _choice_made.emit(c), PORTRAITS.for_monster(c.source))
	if allow_cancel:
		_add_button("Cancel", func(): _choice_made.emit(null))
	monster_prompt_ready.emit(options)
	var chosen: Combatant = await _choice_made
	_clear_dynamic_buttons()
	return chosen


func _clear_dynamic_buttons() -> void:
	for b in _dynamic_buttons:
		b.queue_free()
	_dynamic_buttons.clear()


func _update_hud() -> void:
	_enemy_name.text = "%s    HP %d/%d" % [_enemy.display_name, _enemy.hp, _enemy.max_hp]
	_animate_hp_bar(_enemy_hp, _enemy.hp, _enemy.max_hp)
	if _active != null:
		_player_name.text = "%s    HP %d/%d    (party %d)" % [
			_active.display_name, _active.hp, _active.max_hp, _living_party().size()]
		_animate_hp_bar(_player_hp, _active.hp, _active.max_hp)
	else:
		_player_name.text = "Party: %d monster(s)" % _living_party().size()
		_player_hp.value = 0


## Tween the bar's value to `hp` instead of snapping, and tint its fill green/yellow/red by
## remaining percentage. Each bar gets its own StyleBoxFlat override (created once, reused) so
## this never mutates the shared default theme resource.
func _animate_hp_bar(bar: ProgressBar, hp: int, max_hp: int) -> void:
	bar.max_value = max_hp
	if not _hp_styles.has(bar):
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("fill", sb)
		_hp_styles[bar] = sb
	var pct := float(hp) / float(max_hp) if max_hp > 0 else 0.0
	var color := HP_HIGH_COLOR
	if pct <= 0.25:
		color = HP_LOW_COLOR
	elif pct <= 0.6:
		color = HP_MID_COLOR
	_hp_styles[bar].bg_color = color
	if _hp_tweens.has(bar):
		_hp_tweens[bar].kill()
	var tw := create_tween()
	tw.tween_property(bar, "value", hp, HP_TWEEN_TIME)
	_hp_tweens[bar] = tw


## A floating "+N"/"-N" label near `anchor` that rises and fades out, then frees itself.
func _pop_number(anchor: Control, text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.z_index = 10
	add_child(lbl)
	var start: Vector2 = anchor.global_position + anchor.size / 2.0 - Vector2(10, 10)
	lbl.global_position = start
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position:y", start.y - POPUP_RISE, POPUP_TIME)
	tw.tween_property(lbl, "modulate:a", 0.0, POPUP_TIME)
	tw.chain().tween_callback(lbl.queue_free)


## A brief brighten-flash on `node` (e.g. the enemy sprite) plus a position-jitter shake.
func _hit_feedback(node: CanvasItem) -> void:
	var tw := create_tween()
	tw.tween_property(node, "modulate", FLASH_COLOR, 0.05)
	tw.tween_property(node, "modulate", Color.WHITE, 0.15)
	_shake(node)


## Jitter `node`'s position a few times then settle back exactly where it started.
func _shake(node: Control) -> void:
	var base := node.position
	var tw := create_tween()
	for i in 4:
		var offset := Vector2(_rng.randf_range(-SHAKE_STRENGTH, SHAKE_STRENGTH),
			_rng.randf_range(-SHAKE_STRENGTH, SHAKE_STRENGTH))
		tw.tween_property(node, "position", base + offset, 0.035)
	tw.tween_property(node, "position", base, 0.035)


func _say(text: String) -> void:
	_message.text = text
	await get_tree().create_timer(STEP).timeout


func _sfx(id: String) -> void:
	if _sound != null:
		_sound.play_sfx(id)


func _music(id: String) -> void:
	if _sound != null:
		_sound.play_music(id)
