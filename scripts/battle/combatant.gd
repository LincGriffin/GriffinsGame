class_name Combatant
extends RefCounted
## A runtime combat participant: mutable HP, a per-turn "defending" stance, and the
## monster's moves. Built from a MonsterData — both wild enemies and recruited party
## monsters use the same data. The damage math is static and pure so it can be
## unit-tested without a scene.

var display_name: String
var max_hp: int
var hp: int
var attack: int
var defense: int
var speed: int
var is_boss: bool = false
var is_fused := false             # true if this monster is the result of a merge — a fused monster
                                  # (and fused result) is not an eligible merge partner (never-fused only)
var defending := false
var atk_bonus := 0               # temporary attack buff (from "buff" moves); reset each battle/switch-in
var counter_bonus := 0           # one-shot attack bonus from guard/evade — added to the NEXT attack, then cleared
var source: MonsterData = null   # the static def this came from (null for make())
var moves: Array = []            # Array[MoveData] — copied so run-time grants don't touch the resource

# One-shot defensive stances (from "reflect"/"evade" moves) — like `defending`, these guard
# against exactly the next incoming hit and are consumed (or expire) at the start of the next
# command menu; see battle.gd's _resolve_hit(). "stunned" is different: it's inflicted BY an
# opponent's "stun" move and checked/cleared at the start of the stunned side's own next turn,
# skipping it entirely.
var evading := false     # the next hit against this combatant deals 0 damage
var reflecting := false  # the next hit against this combatant is redirected to its attacker
var stunned := false     # skip this combatant's next turn

# Move cooldowns (move id -> turns remaining) and a charging move (a MoveData mid-charge, or null).
# Both are per-combatant and reset on switch-in; battle.gd drives them (see MoveData.cooldown/charge).
var cooldowns: Dictionary = {}
var charging = null      # a MoveData being charged this turn, fires next turn (null = not charging)


## Count down every cooldown by one turn (called at the start of this combatant's turn).
func tick_cooldowns() -> void:
	for id in cooldowns.keys():
		cooldowns[id] -= 1
		if cooldowns[id] <= 0:
			cooldowns.erase(id)


func on_cooldown(id: String) -> bool:
	return int(cooldowns.get(id, 0)) > 0


## Put move `id` on cooldown for `turns` turns. +1 so it survives the tick on the caster's very
## next turn and is blocked for exactly `turns` of the caster's turns.
func start_cooldown(id: String, turns: int) -> void:
	if turns > 0:
		cooldowns[id] = turns + 1


## Clear all per-turn move state (on switch-in / battle start), same spirit as atk_bonus resetting.
func reset_turn_state() -> void:
	cooldowns.clear()
	charging = null


func is_alive() -> bool:
	return hp > 0


## Apply damage, clamped to [0, max_hp]. Returns the amount actually dealt.
func take_damage(amount: int) -> int:
	var before := hp
	hp = clampi(hp - amount, 0, max_hp)
	return before - hp


static func make(display_name: String, max_hp: int, attack: int, defense: int,
		speed: int, is_boss := false) -> Combatant:
	var c := Combatant.new()
	c.display_name = display_name
	c.max_hp = max_hp
	c.hp = max_hp
	c.attack = attack
	c.defense = defense
	c.speed = speed
	c.is_boss = is_boss
	return c


## Build a full-HP combatant from a monster definition — used for wild enemies and
## for freshly recruited party members alike. Moves are duplicated so that granting a
## monster a new move at run time never mutates the shared MonsterData resource.
static func from_monster(m: MonsterData) -> Combatant:
	var c := make(m.display_name, m.max_hp, m.attack, m.defense, m.speed, m.is_boss)
	c.source = m
	c.moves = m.moves.duplicate()
	return c


## Pure damage formula: attack (+ any temporary buff + the move's power) minus half the
## target's defense, small variance, halved (rounded down) if the target is defending,
## never below 1. Pass a seeded `rng` in tests for determinism, or null to skip variance.
static func compute_damage(attacker: Combatant, target: Combatant,
		rng: RandomNumberGenerator = null, move_power: int = 0) -> int:
	var dmg := attacker.attack + attacker.atk_bonus + move_power - int(floor(target.defense / 2.0))
	if rng != null:
		dmg += rng.randi_range(-1, 1)
	if target.defending:
		dmg = int(floor(dmg / 2.0))
	return maxi(1, dmg)
