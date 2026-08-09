extends SceneTree
## Generates the default fusion recipes into assets/data/fusions/*.tres — special monster-merge
## pairs that produce a specific named monster instead of a generic "Fused <parent>" blend (see
## MonsterMerge/FusionTable). Edit the RECIPES table here to rebalance the built-in set, or use
## the Fusions editor dock (addons/fusion_editor/) to add/edit them in the Godot GUI. Run:
##   Godot_console.exe --headless --path <project> --script res://tools/gen_fusions.gd

const OUT := "res://assets/data/fusions/"
const FUSION_REPO := preload("res://scripts/data/fusion_repo.gd")
const FUSION_RECIPE_DATA := preload("res://scripts/data/fusion_recipe_data.gd")

# parent_a, parent_b, result_id
const RECIPES := [
	["bat", "slime", "wraith"],            # ethereal drip -> a wraith
	["goblin", "skeleton", "gremlin_knob"], # cunning + bone -> the elite gremlin
	["golem", "spider", "griffin"],        # heavy + many-legged -> a griffin
	["chicken", "rat", "goblin"],          # vermin uprising -> a goblin
	["bat", "rat", "spider"],              # scurrying swarm -> a giant spider
	["griffin", "griffin", "hydra"],       # two griffins forged together -> the final-boss species
]


func _init() -> void:
	var da := DirAccess.open("res://")
	da.make_dir_recursive("assets/data/fusions")
	for row in RECIPES:
		var r: FusionRecipeData = FUSION_RECIPE_DATA.new()
		r.parent_a = row[0]
		r.parent_b = row[1]
		r.result_id = row[2]
		r.id = FUSION_REPO.id_for(r.parent_a, r.parent_b)
		var dest: String = OUT + r.id + ".tres"
		var err := ResourceSaver.save(r, dest)
		assert(err == OK, "failed to save " + dest)
		print("wrote ", dest)
	print("gen_fusions: done")
	quit()
