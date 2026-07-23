extends SceneTree
## One-off scene generator — builds player.tscn and overworld.tscn via the engine
## API and packs them, so the .tscn format (ext_resource ids, instancing) is always
## valid. Run headless:
##   Godot_console.exe --headless --path <project> --script res://tools/gen_scenes.gd

func _init() -> void:
	_make_player_scene()
	_make_overworld_scene()
	_make_battle_scene()
	_make_debug_overlay_scene()
	_make_run_scene()
	_make_room_scene()
	print("gen_scenes: done")
	quit()


func _make_player_scene() -> void:
	var player := CharacterBody2D.new()
	player.name = "Player"
	player.set_script(load("res://scripts/player.gd"))

	var spr := Sprite2D.new()
	spr.name = "Sprite2D"
	spr.texture = load("res://assets/sprites/player.png")
	_attach(player, spr)

	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"       # inert now; ready for later Area2D/physics work
	var shape := RectangleShape2D.new()
	shape.size = Vector2(30, 30)
	col.shape = shape
	_attach(player, col)

	var cam := Camera2D.new()
	cam.name = "Camera2D"
	# Tiles are 64px (gen_art.gd), so zoom 1 gives the same on-screen size the old
	# 32px-art-at-zoom-2 did — same chunky crawler view, 4x the pixel detail.
	cam.zoom = Vector2(1, 1)
	_attach(player, cam)

	_save(player, "res://scenes/overworld/player.tscn")


func _make_overworld_scene() -> void:
	var ow := Node2D.new()
	ow.name = "Overworld"
	ow.set_script(load("res://scripts/overworld.gd"))

	var tml := TileMapLayer.new()
	tml.name = "TileMapLayer"
	tml.tile_set = load("res://assets/tilesets/dungeon_tileset.tres")
	_attach(ow, tml)

	# Instance player.tscn (saved above) so overworld.tscn *references* it.
	var player_inst: Node = load("res://scenes/overworld/player.tscn").instantiate()
	player_inst.name = "Player"
	ow.add_child(player_inst)
	player_inst.owner = ow

	_save(ow, "res://scenes/overworld/overworld.tscn")


func _make_battle_scene() -> void:
	var root := CanvasLayer.new()
	root.name = "Battle"
	root.layer = 10                       # draw above the overworld
	root.set_script(load("res://scripts/battle.gd"))

	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.04, 0.05, 0.11, 1.0)   # deep translucent-plastic navy
	_add(root, bg, root)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# A translucent "stage" panel (Magna-Tiles backlit look) sits behind the battle HUD.
	var stage := Panel.new()
	stage.name = "Stage"
	_add(root, stage, root)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["offset_left", "offset_top"]:
		stage.set(side, 18)
	for side in ["offset_right", "offset_bottom"]:
		stage.set(side, -18)
	var stage_sb := StyleBoxFlat.new()
	stage_sb.bg_color = Color(0.20, 0.34, 0.85, 0.16)
	stage_sb.set_border_width_all(2)
	stage_sb.border_color = Color(0.50, 0.68, 1.0, 0.55)
	stage_sb.set_corner_radius_all(20)
	stage_sb.shadow_color = Color(0.30, 0.45, 0.95, 0.30)
	stage_sb.shadow_size = 10
	stage.add_theme_stylebox_override("panel", stage_sb)

	var panel := MarginContainer.new()
	panel.name = "Panel"
	_add(root, panel, root)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		panel.add_theme_constant_override(side, 28)

	var col := VBoxContainer.new()
	col.name = "Col"
	col.add_theme_constant_override("separation", 10)
	_add(panel, col, root)

	var enemy_name := Label.new()
	enemy_name.name = "EnemyName"
	enemy_name.text = "Enemy"
	_add(col, enemy_name, root)

	var enemy_hp := ProgressBar.new()
	enemy_hp.name = "EnemyHP"
	enemy_hp.show_percentage = false
	enemy_hp.custom_minimum_size = Vector2(0, 18)
	_add(col, enemy_hp, root)

	var enemy_area := CenterContainer.new()
	enemy_area.name = "EnemyArea"
	enemy_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_add(col, enemy_area, root)

	var enemy_sprite := ColorRect.new()
	enemy_sprite.name = "EnemySprite"
	enemy_sprite.custom_minimum_size = Vector2(120, 120)
	enemy_sprite.color = Color.WHITE
	_add(enemy_area, enemy_sprite, root)

	var message := Label.new()
	message.name = "Message"
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size = Vector2(0, 48)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(col, message, root)

	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	_add(col, actions, root)

	for label in ["Attack", "Defend", "Flee"]:
		var b := Button.new()
		b.name = label
		b.text = label
		b.custom_minimum_size = Vector2(120, 40)
		_add(actions, b, root)

	var player_name := Label.new()
	player_name.name = "PlayerName"
	player_name.text = "Hero"
	_add(col, player_name, root)

	var player_hp := ProgressBar.new()
	player_hp.name = "PlayerHP"
	player_hp.show_percentage = false
	player_hp.custom_minimum_size = Vector2(0, 18)
	_add(col, player_hp, root)

	_save(root, "res://scenes/battle/battle.tscn")


func _make_debug_overlay_scene() -> void:
	var root := CanvasLayer.new()
	root.name = "DebugOverlay"
	root.layer = 50                       # above everything, including battles
	root.set_script(load("res://scripts/debug_overlay.gd"))

	var bg := ColorRect.new()
	bg.name = "BG"
	bg.color = Color(0, 0, 0, 0.55)
	bg.position = Vector2(8, 8)
	bg.size = Vector2(440, 196)
	_add(root, bg, root)

	var label := Label.new()
	label.name = "Label"
	label.position = Vector2(18, 14)
	label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	label.add_theme_font_size_override("font_size", 14)
	_add(root, label, root)

	_save(root, "res://scenes/ui/debug_overlay.tscn")


func _make_run_scene() -> void:
	# The node-map run controller (the main scene). Just a Node + script; the map view
	# and battle/banner overlays are all built in code at runtime.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/map/"))
	var root := Node.new()
	root.name = "Run"
	root.set_script(load("res://scripts/run.gd"))
	_save(root, "res://scenes/map/run.tscn")


func _make_room_scene() -> void:
	# A walkable treasure room (Node2D + TileMapLayer + Player) opened by "room" nodes.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/map/"))
	var root := Node2D.new()
	root.name = "Room"
	root.set_script(load("res://scripts/room.gd"))
	var tml := TileMapLayer.new()
	tml.name = "TileMapLayer"
	tml.tile_set = load("res://assets/tilesets/dungeon_tileset.tres")
	_attach(root, tml)
	var player_inst: Node = load("res://scenes/overworld/player.tscn").instantiate()
	player_inst.name = "Player"
	root.add_child(player_inst)
	player_inst.owner = root
	_save(root, "res://scenes/map/room.tscn")


func _attach(root: Node, child: Node) -> void:
	root.add_child(child)
	child.owner = root


## Add `child` under `parent`, but owned by the scene `root` so it serializes.
func _add(parent: Node, child: Node, root: Node) -> void:
	parent.add_child(child)
	child.owner = root


func _save(root: Node, path: String) -> void:
	var ps := PackedScene.new()
	var err := ps.pack(root)
	assert(err == OK, "pack failed for %s" % path)
	err = ResourceSaver.save(ps, path)
	assert(err == OK, "save failed for %s" % path)
