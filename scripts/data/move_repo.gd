class_name MoveRepo
extends RefCounted
## Read-only lookup over the move roster (`assets/data/moves/*.tres`) — the monster editor
## dock uses this to offer moves for a monster's moveset. Moves themselves are still
## authored via tools/gen_moves.gd; this is just a listing helper.

const DIR := "res://assets/data/moves/"


static func list_ids() -> Array[String]:
	var ids: Array[String] = []
	var da := DirAccess.open(DIR)
	if da == null:
		return ids
	for f in da.get_files():
		if f.ends_with(".tres"):
			ids.append(f.get_basename())
	ids.sort()
	return ids


static func load_all() -> Array[MoveData]:
	var out: Array[MoveData] = []
	for id in list_ids():
		var mv := load(DIR + id + ".tres") as MoveData
		if mv != null:
			out.append(mv)
	return out
