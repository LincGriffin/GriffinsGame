extends "res://tools/tests/_base.gd"
## Phase 4 (Magna-Tiles art): the generated art has the expected shape, and the map view
## gives each node type its own translucent-plastic chip style. Pixels/aesthetics are
## verified by eye; these guard the contract the generators and MapView promise.

func test_tileset_png_dimensions() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(
		"res://assets/tilesets/dungeon_tiles.png"))
	check(img != null, "dungeon_tiles.png loads")
	if img == null:
		return
	eq(img.get_width(), 288, "tileset strip is 9 tiles (288px) wide")
	eq(img.get_height(), 32, "tileset strip is one tile (32px) tall")


func test_player_sprite_is_a_gem_on_transparency() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(
		"res://assets/sprites/player.png"))
	check(img != null, "player.png loads")
	if img == null:
		return
	eq(img.get_width(), 32, "player sprite is 32px wide")
	eq(img.get_height(), 32, "player sprite is 32px tall")
	# A gem on transparent backing: the corners are clear, the center is opaque.
	check(img.get_pixel(0, 0).a == 0.0, "corner pixel is transparent")
	check(img.get_pixel(16, 16).a > 0.5, "center pixel is opaque (the gem body)")


func test_map_view_styles_each_node_type() -> void:
	var view := MapView.new()
	runner.root.add_child(view)
	var map := {
		"nodes": [
			{"id": 0, "row": 0, "col": 0, "type": "battle", "to": [1]},
			{"id": 1, "row": 1, "col": 0, "type": "room", "to": [2]},
			{"id": 2, "row": 2, "col": 0, "type": "boss", "to": []},
		],
		"start_row_nodes": [0], "boss": 2, "rows": 3,
	}
	view.setup(map)
	await idle()
	var buttons := view.get_children().filter(func(c): return c is Button)
	eq(buttons.size(), 3, "one button per node")
	for b in buttons:
		check(b.has_theme_stylebox_override("normal"),
			"node button carries a plastic-chip stylebox")
	view.queue_free()
	await idle()
