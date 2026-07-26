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
const MONSTER_DATA := preload("res://scripts/data/monster_data.gd")
const MONSTERS_DIR := "res://assets/data/monsters/"
const MOVES_DIR := "res://assets/data/moves/"

# The player's chosen starter fights alone against a scaling wild roster early on, so it
# gets a one-time boost over its base stats (recruits later stay at their base stats).
const STARTER_HP_MULT := 1.4
const STARTER_ATK_BONUS := 3
const STARTER_DEF_BONUS := 1

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
		c.defense += STARTER_DEF_BONUS
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


## Fuse a NEWLY CAPTURED monster (not yet in the party) with an existing `partner`. The capture
## is spent into the fusion (never added on its own) and `partner` is replaced by the result, so
## the party size is UNCHANGED — the post-battle "merge the new monster?" offer (see run.gd). The
## `partner` should be a never-fused member (`not is_fused`); the fused result is `is_fused`.
func merge_incoming(partner: Combatant, incoming: MonsterData) -> Combatant:
	var fused: Combatant = MONSTER_MERGE.fuse(partner, Combatant.from_monster(incoming))
	party = party.filter(func(c): return c != partner)
	party.append(fused)
	party_changed.emit()
	return fused


## Living members that have never been part of a fusion — the eligible partners for merge_incoming.
func unfused_living() -> Array:
	return living().filter(func(c): return not c.is_fused)


## Drop any monsters that were knocked out — permadeath for the rest of the run.
func prune_dead() -> void:
	var before := party.size()
	party = party.filter(func(c): return c.is_alive())
	if party.size() != before:
		party_changed.emit()


# --- Save/resume serialization (Phase 19 scaffold; see scripts/data/save_game.gd) ---

## Serialize the party to plain Dictionaries for a SaveGame. Stores each Combatant's FULL live state
## (not just a monster id), so a run-time MERGED monster — whose MonsterData is generated in memory
## with no file on disk — round-trips intact (name / stats / tint / moves). `source_id` is the
## on-disk MonsterData id when there is one (for portrait/map-sprite lookup), else "".
func serialize_party() -> Array:
	var out: Array = []
	for c in party:
		var move_ids: Array = []
		for mv in c.moves:
			move_ids.append(String(mv.id))
		out.append({
			"source_id": String(c.source.id) if c.source != null else "",
			"display_name": c.display_name,
			"max_hp": c.max_hp,
			"hp": c.hp,
			"attack": c.attack,
			"defense": c.defense,
			"speed": c.speed,
			"is_boss": c.is_boss,
			"is_fused": c.is_fused,
			"atk_bonus": c.atk_bonus,
			"tint": c.source.tint if c.source != null else Color(0.6, 0.6, 0.6),
			"move_ids": move_ids,
		})
	return out


## Rebuild the party from serialize_party() output, replacing the current party.
func restore_party(data: Array) -> void:
	party.clear()
	for e in data:
		party.append(_combatant_from_save(e))
	party_changed.emit()


## Reconstruct one Combatant from a saved dict. Loads the on-disk MonsterData when `source_id`
## resolves (for identity/art), otherwise builds a synthetic one from the saved name/tint — the
## fused-monster case. Live stats and moves always come from the save, not the base data.
func _combatant_from_save(e: Dictionary) -> Combatant:
	var source_id := String(e.get("source_id", ""))
	var md: MonsterData = null
	var path := MONSTERS_DIR + source_id + ".tres"
	if source_id != "" and ResourceLoader.exists(path):
		md = load(path) as MonsterData
	else:
		md = MONSTER_DATA.new()
		md.id = source_id
		md.display_name = String(e.get("display_name", "Monster"))
		md.tint = e.get("tint", Color(0.6, 0.6, 0.6))
	var c := Combatant.new()
	c.source = md
	c.display_name = String(e.get("display_name", md.display_name))
	c.max_hp = int(e.get("max_hp", 1))
	c.hp = int(e.get("hp", c.max_hp))
	c.attack = int(e.get("attack", 0))
	c.defense = int(e.get("defense", 0))
	c.speed = int(e.get("speed", 0))
	c.is_boss = bool(e.get("is_boss", false))
	c.is_fused = bool(e.get("is_fused", false))
	c.atk_bonus = int(e.get("atk_bonus", 0))
	var moves: Array = []
	for mid in e.get("move_ids", []):
		var mpath := MOVES_DIR + String(mid) + ".tres"
		if ResourceLoader.exists(mpath):
			moves.append(load(mpath))
	c.moves = moves
	return c
