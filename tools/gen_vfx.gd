extends SceneTree
## Move visual-effect generator — writes self-contained one-shot particle scenes to
## assets/vfx/<id>.tscn. Each is a Node2D (running scripts/vfx_oneshot.gd, which fires the burst
## on spawn and frees itself) + a CPUParticles2D tuned per effect. CPUParticles2D (not GPU) because
## the project renders with GL Compatibility (project.godot), where GPU particles are unreliable.
##
## A move references one of these by id via MoveData.vfx (see VfxLibrary / battle.gd). Moves SHARE
## an effect by naming the same id, and SWAP one by pointing at a different id or dropping a new
## .tscn at the same path. Re-run after editing EFFECTS:
##   Godot_console.exe --headless --path <project> --script res://tools/gen_vfx.gd
##
## Uses load() for the script (not the class name) so a fresh checkout doesn't depend on the global
## class cache being built first — same reasoning as the other generators.

const OUT_DIR := "res://assets/vfx/"
const ONESHOT_SCRIPT := "res://scripts/vfx_oneshot.gd"

# id -> particle config. color/velocity/gravity/scale shape the burst; every effect is a one-shot,
# fully-explosive burst emitted from a point. Keep ids in sync with tools/gen_moves.gd's vfx column.
const EFFECTS := {
	"slash":        {"amount": 24, "life": 0.35, "vmin": 220, "vmax": 380, "grav": Vector2.ZERO,        "smin": 3.0, "smax": 6.0, "spread": 180, "dir": Vector2.RIGHT, "color": Color(0.80, 0.95, 1.00)},
	"impact":       {"amount": 30, "life": 0.45, "vmin": 120, "vmax": 300, "grav": Vector2(0, 300),     "smin": 5.0, "smax": 9.0, "spread": 180, "dir": Vector2.UP,    "color": Color(0.92, 0.92, 0.96)},
	"heal_sparkle": {"amount": 20, "life": 0.60, "vmin": 60,  "vmax": 140, "grav": Vector2(0, -40),     "smin": 3.0, "smax": 5.0, "spread": 40,  "dir": Vector2.UP,    "color": Color(0.42, 0.95, 0.52)},
	"buff_glow":    {"amount": 24, "life": 0.50, "vmin": 80,  "vmax": 160, "grav": Vector2.ZERO,        "smin": 4.0, "smax": 7.0, "spread": 180, "dir": Vector2.RIGHT, "color": Color(1.00, 0.82, 0.30)},
	"drain_wisp":   {"amount": 18, "life": 0.55, "vmin": 80,  "vmax": 160, "grav": Vector2(0, -60),     "smin": 3.0, "smax": 6.0, "spread": 60,  "dir": Vector2.UP,    "color": Color(0.60, 0.35, 0.80)},
	"merge":        {"amount": 40, "life": 0.60, "vmin": 180, "vmax": 340, "grav": Vector2.ZERO,        "smin": 5.0, "smax": 9.0, "spread": 180, "dir": Vector2.RIGHT, "color": Color(1.00, 0.92, 0.55)},
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var oneshot: GDScript = load(ONESHOT_SCRIPT)
	for id in EFFECTS:
		_write_effect(id, EFFECTS[id], oneshot)
	print("gen_vfx: done (%d effects)" % EFFECTS.size())
	quit()


func _write_effect(id: String, cfg: Dictionary, oneshot: GDScript) -> void:
	var root := Node2D.new()
	root.name = id
	root.set_script(oneshot)
	root.set("life", float(cfg["life"]) + 0.2)

	var p := CPUParticles2D.new()
	p.name = "Particles"
	p.emitting = false           # vfx_oneshot fires it on spawn
	p.one_shot = true
	p.explosiveness = 1.0         # a single burst, not a stream
	p.amount = int(cfg["amount"])
	p.lifetime = float(cfg["life"])
	p.direction = cfg["dir"]
	p.spread = float(cfg["spread"])
	p.gravity = cfg["grav"]
	p.initial_velocity_min = float(cfg["vmin"])
	p.initial_velocity_max = float(cfg["vmax"])
	p.scale_amount_min = float(cfg["smin"])
	p.scale_amount_max = float(cfg["smax"])
	p.color = cfg["color"]
	root.add_child(p)
	p.owner = root               # required so pack() includes the child

	var packed := PackedScene.new()
	var err := packed.pack(root)
	assert(err == OK, "failed to pack " + id)
	var path := OUT_DIR + id + ".tscn"
	err = ResourceSaver.save(packed, path)
	assert(err == OK, "failed to save " + path)
	print("wrote ", path)
	root.free()
