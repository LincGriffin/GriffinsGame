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
const MOVES := [
	{"id": "strike", "name": "Strike",     "kind": "attack", "power": 0, "desc": "A reliable hit."},
	{"id": "heavy",  "name": "Heavy Blow",  "kind": "attack", "power": 5, "desc": "A powerful strike."},
	{"id": "guard",  "name": "Guard",       "kind": "guard",  "power": 0, "desc": "Brace — halve the next hit."},
	{"id": "mend",   "name": "Mend",        "kind": "heal",   "power": 8, "desc": "Recover some HP."},
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
