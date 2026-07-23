extends SceneTree
## Content generator — writes the move roster to assets/data/moves/*.tres.
## Edit the MOVES table below and re-run (run BEFORE gen_content, which references
## these moves):
##   Godot_console.exe --headless --path <project> --script res://tools/gen_moves.gd
##
## Uses load() for the MoveData script (not the class_name) so a freshly written data
## class doesn't depend on the global class cache being rebuilt first.

const OUT_DIR := "res://assets/data/moves/"

# id, name, kind, power, description
# kinds: attack (deal dmg) · guard (halve next hit) · evade (next hit deals 0 dmg) ·
#        reflect (next hit is redirected to its attacker) · heal (restore power HP) ·
#        drain (deal dmg, heal user half the damage) · buff (raise user's attack by power) ·
#        stun (deal dmg, target skips its next turn) · reckless (heavy dmg, user takes recoil)
const MOVES := [
	{"id": "strike",  "name": "Strike",         "kind": "attack",   "power": 0,  "desc": "A reliable hit."},
	{"id": "heavy",   "name": "Heavy Blow",      "kind": "attack",   "power": 5,  "desc": "A powerful strike."},
	{"id": "slam",    "name": "Slam",            "kind": "attack",   "power": 9,  "desc": "A crushing blow."},
	{"id": "guard",   "name": "Guard",           "kind": "guard",    "power": 0,  "desc": "Brace — halve the next hit."},
	{"id": "evade",   "name": "Evade",           "kind": "evade",    "power": 0,  "desc": "Slip away — the next hit misses entirely."},
	{"id": "reflect", "name": "Reflect",         "kind": "reflect",  "power": 0,  "desc": "Brace and reflect the next hit back at its attacker."},
	{"id": "mend",    "name": "Mend",            "kind": "heal",     "power": 8,  "desc": "Recover some HP."},
	{"id": "drain",   "name": "Drain",           "kind": "drain",    "power": 2,  "desc": "Bite and siphon — heal for half the damage."},
	{"id": "focus",   "name": "Focus",           "kind": "buff",     "power": 3,  "desc": "Steel yourself — raise attack for the fight."},
	{"id": "shock",   "name": "Shock",           "kind": "stun",     "power": 4,  "desc": "A jolting strike — the target reels and can't act next turn."},
	{"id": "reckless_swing", "name": "Reckless Swing", "kind": "reckless", "power": 14, "desc": "A wild, all-out swing that hurts the user too."},
]


func _init() -> void:
	var script: GDScript = load("res://scripts/data/move_data.gd")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for row in MOVES:
		var mv = script.new()
		mv.id = row.id
		mv.display_name = row.name
		mv.kind = row.kind
		mv.power = row.power
		mv.description = row.desc
		var path := OUT_DIR + str(row.id) + ".tres"
		var err := ResourceSaver.save(mv, path)
		assert(err == OK, "failed to save " + path)
		print("wrote ", path)
	print("gen_moves: done")
	quit()
