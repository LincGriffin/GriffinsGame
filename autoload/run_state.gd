extends Node
## Persistent state for the current run: the player's party of monsters — each with
## its own current HP, carried between battles — plus the run lifecycle. Registered as
## the autoload singleton `RunState`. There is no "Hero": every fighter is a monster,
## and a run ends only when the whole party is knocked out (permadeath — a downed
## monster is gone for the rest of the run). Nothing persists between runs.

signal party_changed

const PARTY_CAP := 5

## Array[Combatant] — the run's living monsters, each carrying its current hp.
var party: Array = []


## Begin a fresh run with `starter` as the sole party member. Pass null to clear the
## party (e.g. on game over, before the player picks a new starter).
func new_run(starter: MonsterData) -> void:
	party.clear()
	if starter != null:
		party.append(Combatant.from_monster(starter))
	party_changed.emit()


## The monsters that can still fight.
func living() -> Array:
	return party.filter(func(c): return c.is_alive())


func has_living() -> bool:
	return not living().is_empty()


func is_full() -> bool:
	return party.size() >= PARTY_CAP


## Recruit a defeated wild monster as a fresh, full-HP party member. Returns false
## (and adds nothing) when the party is already at the cap — Phase 1 simply skips;
## a later phase adds replace / merge.
func add_monster(m: MonsterData) -> bool:
	if is_full():
		return false
	party.append(Combatant.from_monster(m))
	party_changed.emit()
	return true


## Drop any monsters that were knocked out — permadeath for the rest of the run.
func prune_dead() -> void:
	var before := party.size()
	party = party.filter(func(c): return c.is_alive())
	if party.size() != before:
		party_changed.emit()
