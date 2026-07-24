class_name FusionTable
extends RefCounted
## Special monster-merge results (Phase 6). MOST parent pairs fuse into a generic "Fused" blend
## (see MonsterMerge); the pairs listed here instead become a specific, distinct monster — a
## "whole new monster" from the player's point of view, with its own portrait/map sprite/name.
##
## Keyed by the two parent monster ids joined with "|" in SORTED order, so order doesn't matter.
## Values are the result monster's id (a real `assets/data/monsters/<id>.tres`). Edit freely to add
## thematic recipes; an unlisted pair just falls through to the generic fusion.

const TABLE := {
	"bat|slime": "wraith",        # ethereal drip -> a wraith
	"goblin|skeleton": "gremlin_knob",  # cunning + bone -> the elite gremlin
	"golem|spider": "griffin",    # heavy + many-legged -> a griffin
	"chicken|rat": "goblin",      # vermin uprising -> a goblin
	"bat|rat": "spider",          # scurrying swarm -> a giant spider
}


## The result monster id for a parent pair, or "" if the pair has no special recipe (→ generic).
static func lookup(id_a: String, id_b: String) -> String:
	if id_a.is_empty() or id_b.is_empty():
		return ""
	var pair := [id_a, id_b]
	pair.sort()
	return TABLE.get("%s|%s" % [pair[0], pair[1]], "")
