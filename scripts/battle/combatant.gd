class_name Combatant
extends RefCounted
## A runtime combat participant: mutable HP plus a per-turn "defending" stance.
## Built from an EnemyData (enemies) or from GameState's fields (the player).
## The damage math is static and pure so it can be unit-tested without a scene.

var display_name: String
var max_hp: int
var hp: int
var attack: int
var defense: int
var speed: int
var is_boss: bool = false
var defending := false


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


static func from_enemy(e: EnemyData) -> Combatant:
	return make(e.display_name, e.max_hp, e.attack, e.defense, e.speed, e.is_boss)


## Pure damage formula: attack minus half the target's defense, small variance,
## halved (rounded down) if the target is defending, never below 1. Pass a seeded
## `rng` in tests for determinism, or null to skip variance entirely.
static func compute_damage(attacker: Combatant, target: Combatant,
		rng: RandomNumberGenerator = null) -> int:
	var dmg := attacker.attack - int(floor(target.defense / 2.0))
	if rng != null:
		dmg += rng.randi_range(-1, 1)
	if target.defending:
		dmg = int(floor(dmg / 2.0))
	return maxi(1, dmg)
