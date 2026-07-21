extends SceneTree
## One-off scene generator — builds player.tscn and overworld.tscn via the engine
## API and packs them, so the .tscn format (ext_resource ids, instancing) is always
## valid. Run headless:
##   Godot_console.exe --headless --path <project> --script res://tools/gen_scenes.gd

func _init() -> void:
	_make_player_scene()
	_make_overworld_scene()
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
	cam.zoom = Vector2(2, 2)             # chunky, close-in crawler view
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


func _attach(root: Node, child: Node) -> void:
	root.add_child(child)
	child.owner = root


func _save(root: Node, path: String) -> void:
	var ps := PackedScene.new()
	var err := ps.pack(root)
	assert(err == OK, "pack failed for %s" % path)
	err = ResourceSaver.save(ps, path)
	assert(err == OK, "save failed for %s" % path)
