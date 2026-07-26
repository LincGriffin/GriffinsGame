extends SceneTree
## Screenshot harness — renders real screens/overlays and saves them as PNGs to `screenshots/`, so
## UI changes can actually be LOOKED AT instead of only asserted about.
##
## ⚠ Run this WITHOUT `--headless`. Headless uses the dummy display driver: there is no rendering
## context, so the viewport capture comes back empty. This is the one tool in `tools/` that needs a
## real window (it opens briefly, captures, and quits on its own).
##
##   # every shot
##   "$GODOT" --path "C:\\Users\\Dad\\GriffinsGame" --script res://tools/screenshot.gd
##   # one shot
##   "$GODOT" --path "C:\\Users\\Dad\\GriffinsGame" --script res://tools/screenshot.gd -- dungeon
##
## Shots whose script/scene doesn't exist on the current branch are SKIPPED, not failed — so the
## same tool works while a UI is still on a feature branch.

const OUT_DIR := "res://screenshots/"
const SIZE := Vector2i(1152, 648)
const SETTLE_FRAMES := 30   # let _ready, layout and intro tweens settle before capturing

const SHOTS := ["title", "starter_select", "dungeon", "battle", "powerup_select", "merge_select", "vfx"]

const MONSTERS := "res://assets/data/monsters/"


func _init() -> void:
	_run()


func _run() -> void:
	DisplayServer.window_set_size(SIZE)
	DirAccess.open("res://").make_dir_recursive("screenshots")
	var only := _requested_shot()
	var names: Array = SHOTS if only.is_empty() else [only]
	for name in names:
		await _shoot(String(name))
	print("screenshot: done -> %s" % OUT_DIR)
	quit()


## The shot name after a bare `--` on the command line, or "" for all of them.
func _requested_shot() -> String:
	var args := OS.get_cmdline_user_args()
	return String(args[0]) if args.size() > 0 else ""


func _shoot(name: String) -> void:
	# Every shot starts from an empty root. Shots leak into each other otherwise: a leftover
	# RunState (they're all named "RunState") makes the next one's fixture the second node with
	# that name, so `/root/RunState` resolves to the stale one and the screen renders an empty
	# party. Cheaper to guarantee isolation than to reason about teardown order.
	await _clear_root()
	var nodes: Array = _build(name)
	if nodes.is_empty():
		print("  %-16s skipped (not on this branch)" % name)
		return
	# Move effects are transient one-shot particle bursts that self-free — capture mid-burst.
	var settle := 6 if name == "vfx" else SETTLE_FRAMES
	for i in settle:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var path := OUT_DIR + name + ".png"
	var err := img.save_png(path) if img != null else FAILED
	print("  %-16s -> %s [%s]" % [name, path, "ok" if err == OK else "ERR %d" % err])


## Drop everything under root and let the frees settle before the next shot builds.
func _clear_root() -> void:
	for c in root.get_children():
		root.remove_child(c)
		c.free()
	await process_frame


## Build the scene/overlay for a shot. Returns the nodes added to `root` (freed after capture), or
## [] when this branch doesn't have the thing.
func _build(name: String) -> Array:
	match name:
		"title":
			return [_add(load("res://scenes/map/run.tscn").instantiate())]
		"starter_select":
			if not ResourceLoader.exists("res://scripts/starter_select.gd"):
				return []
			var sel = load("res://scripts/starter_select.gd").new()
			sel.setup([_m("chicken"), _m("slime"), _m("bat")])
			return [_add(sel)]
		"dungeon":
			return _build_dungeon()
		"battle":
			var rs := _run_state(["chicken", "bat"])
			var battle = load("res://scenes/battle/battle.tscn").instantiate()
			battle.STEP = 0.01           # don't sit through the intro pacing
			battle.setup(_m("goblin"))
			return [rs, _add(battle)]
		"powerup_select":
			if not ResourceLoader.exists("res://scripts/powerup_select.gd"):
				return []
			var rs2 := _run_state(["chicken", "bat", "slime"])
			var run = _detached_run(rs2)
			var sel2 = load("res://scripts/powerup_select.gd").new()
			sel2.setup(run._build_upgrade_options(), rs2.living())
			run.free()
			return [rs2, _add(sel2)]
		"merge_select":
			if not ResourceLoader.exists("res://scripts/merge_select.gd"):
				return []
			var rs3 := _run_state(["chicken", "bat", "slime"])
			var sel3 = load("res://scripts/merge_select.gd").new()
			# The post-capture merge offer: fuse the newly captured monster with a party member.
			sel3.setup_offer(_m("goblin"), rs3.living(), false)
			return [rs3, _add(sel3)]
		"vfx":
			return _build_vfx()
	return []


## Lays out the shipped move effects mid-burst on a dark backdrop, each labelled, so the
## CPUParticles2D effects can be eyeballed (they render fine under GL Compatibility).
func _build_vfx() -> Array:
	if not ResourceLoader.exists("res://scripts/data/vfx_library.gd"):
		return []
	var vfx := load("res://scripts/data/vfx_library.gd")
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.09)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var out: Array = [_add(bg)]
	var ids := ["slash", "impact", "heal_sparkle", "buff_glow", "drain_wisp"]
	for i in ids.size():
		var scene: PackedScene = vfx.for_id(ids[i])
		if scene == null:
			continue
		var fx = scene.instantiate()
		fx.position = Vector2(180 + (i % 3) * 400, 200 + (i / 3) * 260)
		out.append(_add(fx))
		var lbl := Label.new()
		lbl.text = ids[i]
		lbl.position = fx.position - Vector2(40, 90)
		out.append(_add(lbl))
	return out


## The walkable dungeon with a real generated map (plus the roster HUD when the branch has one).
func _build_dungeon() -> Array:
	var rs := _run_state(["chicken", "bat", "slime"])
	var run = _detached_run(rs)
	var map: Dictionary = load("res://scripts/map/map_generator.gd").new().generate(run._rng)
	run._map = map
	run._assign_encounters()
	var out: Array = [rs]
	var view = load("res://scripts/map/dungeon_view.gd").new()
	out.append(_add(view))
	view.setup(map)
	# Dress the player as the lead monster when that feature is on this branch.
	if view.player != null and view.player.has_method("set_monster_appearance"):
		view.player.set_monster_appearance(rs.party[0].source)
	if ResourceLoader.exists("res://scripts/roster_hud.gd"):
		var hud = load("res://scripts/roster_hud.gd").new()
		if hud.has_method("setup"):
			hud.setup(rs)
		out.append(_add(hud))
	run.free()
	return out


## A live RunState registered at /root/RunState (what the game's scripts look up), seeded with a
## party built from monster ids.
func _run_state(ids: Array) -> Node:
	var rs = load("res://autoload/run_state.gd").new()
	rs.name = "RunState"
	root.add_child(rs)
	rs.new_run(_m(ids[0]))
	for i in range(1, ids.size()):
		rs.add_monster(_m(ids[i]))
	return rs


## A Run instance that is NOT in the tree — just for reusing its real pickers/option builders.
func _detached_run(rs: Node):
	var run = load("res://scripts/run.gd").new()
	run._gs = rs
	run._rng.randomize()
	run._build_wild_index()
	return run


func _m(id) -> MonsterData:
	return load(MONSTERS + String(id) + ".tres") as MonsterData


func _add(n: Node) -> Node:
	root.add_child(n)
	return n
