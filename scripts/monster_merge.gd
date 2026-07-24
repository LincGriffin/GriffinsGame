class_name MonsterMerge
extends RefCounted
## Fuses two party monsters into one (Phase 6 monster merge). Pure/static so it's unit-tested
## without a scene (test_monster_merge.gd).
##
## - **Identity:** a special parent pair (FusionTable) becomes that distinct monster — real name,
##   portrait, map sprite. Every other pair becomes a **generic "Fused <stronger parent>"** with a
##   blended tint and no portrait (falls back to the tint swatch), so it reads as clearly new.
## - **Stats:** the per-stat MAX of the two parents plus a small bonus — never the additive sum, so
##   it stays a modest upgrade over the better parent.
## - **Moves:** the UNION of both movesets, de-duplicated by id (capped at MAX_MOVES).
##
## The result is always a full-HP Combatant, ready to drop straight into the party.

const FUSION_TABLE := preload("res://scripts/data/fusion_table.gd")
const MONSTER_DATA := preload("res://scripts/data/monster_data.gd")
const MONSTERS_DIR := "res://assets/data/monsters/"

const HP_MULT := 1.2      # of the higher parent's max HP
const ATK_BONUS := 2
const DEF_BONUS := 2
const MAX_MOVES := 6


static func fuse(a: Combatant, b: Combatant) -> Combatant:
	var c := Combatant.from_monster(_identity(a, b))
	c.max_hp = int(ceil(max(a.max_hp, b.max_hp) * HP_MULT))
	c.hp = c.max_hp
	c.attack = int(max(a.attack, b.attack)) + ATK_BONUS
	c.defense = int(max(a.defense, b.defense)) + DEF_BONUS
	c.speed = int(max(a.speed, b.speed))   # ignored for turn order, kept sane anyway
	c.moves = _merged_moves(a, b)
	return c


## The display name the fused result will have — used by the merge prompt's live preview.
static func result_name(a: Combatant, b: Combatant) -> String:
	return _identity(a, b).display_name


## The MonsterData the result borrows its identity (name / portrait / tint / source) from — a real
## roster monster for a table pair, else a synthetic in-memory "Fused" definition.
static func _identity(a: Combatant, b: Combatant) -> MonsterData:
	var target_id := FUSION_TABLE.lookup(_id(a), _id(b))
	if not target_id.is_empty():
		var md := load(MONSTERS_DIR + target_id + ".tres") as MonsterData
		if md != null:
			return md
	var g: MonsterData = MONSTER_DATA.new()
	g.id = ""                                   # empty id → no portrait/map sprite → tint fallback
	g.display_name = "Fused %s" % _stronger(a, b).display_name
	g.tint = _tint(a).lerp(_tint(b), 0.5)
	return g


## Union of both parents' moves, de-duplicated by id, capped at MAX_MOVES (parent `a` first).
static func _merged_moves(a: Combatant, b: Combatant) -> Array:
	var out: Array = []
	var seen := {}
	for src in [a, b]:
		for mv in src.moves:
			if seen.has(mv.id):
				continue
			seen[mv.id] = true
			out.append(mv)
			if out.size() >= MAX_MOVES:
				return out
	return out


## The "stronger" parent — higher tier, ties broken by max HP — used for the generic fused name.
static func _stronger(a: Combatant, b: Combatant) -> Combatant:
	var ta := _tier(a)
	var tb := _tier(b)
	if ta != tb:
		return a if ta > tb else b
	return a if a.max_hp >= b.max_hp else b


static func _id(c: Combatant) -> String:
	return String(c.source.id) if c.source != null else ""


static func _tier(c: Combatant) -> int:
	return int(c.source.tier) if c.source != null else 0


static func _tint(c: Combatant) -> Color:
	return c.source.tint if c.source != null else Color(0.6, 0.6, 0.6)
