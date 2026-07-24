extends Node
## Persistent state for the current run: the player's party of monsters — each with
## its own current HP, carried between battles — plus the run lifecycle. Registered as
## the autoload singleton `RunState`. There is no "Hero": every fighter is a monster,
## and a run ends only when the whole party is knocked out (permadeath — a downed
## monster is gone for the rest of the run). Nothing persists between runs.

signal party_changed

const PARTY_CAP := 5

## Preloaded (not referenced by class_name) so this autoload compiles regardless of class-cache
## build order — same reasoning as the /root lookups elsewhere.
const MONSTER_MERGE := preload("res://scripts/monster_merge.gd")

# The player's chosen starter fights alone against a scaling wild roster early on, so it
# gets a one-time boost over its base stats (recruits later stay at their base stats).
const STARTER_HP_MULT := 1.3
const STARTER_ATK_BONUS := 2

## Array[Combatant] — the run's living monsters, each carrying its current hp.
var party: Array = []


## Begin a fresh run with `starter` as the sole party member. Pass null to clear the
## party (e.g. on game over, before the player picks a new starter).
func new_run(starter: MonsterData) -> void:
	party.clear()
	if starter != null:
		var c := Combatant.from_monster(starter)
		c.max_hp = int(round(c.max_hp * STARTER_HP_MULT))
		c.hp = c.max_hp
		c.attack += STARTER_ATK_BONUS
		party.append(c)
	party_changed.emit()


## The monsters that can still fight.
func living() -> Array:
	return party.filter(func(c): return c.is_alive())


func has_living() -> bool:
	return not living().is_empty()


func is_full() -> bool:
	return party.size() >= PARTY_CAP


## Recruit a defeated wild monster as a fresh, full-HP party member. Returns false
## (and adds nothing) when the party is already at the cap — the caller then offers a
## merge (see `merge`) to free a slot, or skips the recruit.
func add_monster(m: MonsterData) -> bool:
	if is_full():
		return false
	party.append(Combatant.from_monster(m))
	party_changed.emit()
	return true


## Fuse two party members into one (Phase 6 monster merge). Removes both `a` and `b` and appends
## the fused Combatant, so the party shrinks by one — freeing a slot the caller can then recruit
## into. Returns the fused monster. See MonsterMerge for the fusion rules.
func merge(a: Combatant, b: Combatant) -> Combatant:
	var fused: Combatant = MONSTER_MERGE.fuse(a, b)
	party = party.filter(func(c): return c != a and c != b)
	party.append(fused)
	party_changed.emit()
	return fused


## Drop any monsters that were knocked out — permadeath for the rest of the run.
func prune_dead() -> void:
	var before := party.size()
	party = party.filter(func(c): return c.is_alive())
	if party.size() != before:
		party_changed.emit()
