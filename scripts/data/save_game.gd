class_name SaveGame
extends Resource
## The typed schema for a saved run — serialized to `user://savegame.tres` by SaveSlot.
##
## SCAFFOLD (Phase 19): the schema, storage round-trip (SaveSlot), and party (de)serialization
## (RunState.serialize_party / restore_party) are built and tested, but run.gd does not yet capture
## or restore a live run into one of these, and the title screen has no "Resume" button. The
## save/resume WIRING is the follow-up phase; this class defines the contract it will fill.
##
## `party` holds per-Combatant Dictionaries (see RunState.serialize_party) rather than Combatant
## refs, because a Combatant is a RefCounted (not a Resource) and a MERGED monster's MonsterData is
## generated at run time with no file on disk — so full stats/name/moves are stored, not just an id.

const VERSION := 1

@export var version: int = VERSION
@export var starter_id: String = ""
@export var party: Array = []              # Array[Dictionary] — RunState.serialize_party() output
@export var cleared_room_ids: Array = []   # Array[int] — dungeon rooms already resolved
@export var player_cell: Vector2i = Vector2i.ZERO
@export var map_data: Dictionary = {}      # the serialized DAG + assigned encounters (wired later)
@export var map_seed: int = 0              # the rng seed the map was generated from (wired later)

# Run-tracking counters mirrored from run.gd (so a resumed run keeps an accurate history record).
@export var nodes_resolved: int = 0
@export var battles_fought: int = 0
@export var recruited: Array = []          # Array[String] monster ids recruited so far
@export var died_to: String = ""
@export var died_at_row: int = -1
