extends CanvasLayer
## Autoloaded debug HUD, toggled with F3 (the `toggle_debug` action). Shows FPS,
## player stats, whether a battle is active, and the player's grid cell + the tile
## beneath them. It finds the live nodes via groups ("player", "battle") so it works
## in any scene without wiring. A couple of test cheats are available while open.

@onready var _label: Label = $Label

var _shown := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = _shown


func _process(_delta: float) -> void:
	if _shown:
		_label.text = _build_text()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		_shown = not _shown
		visible = _shown
		return
	if not _shown or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_H:                       # toggle hold-to-move
			var p := _player()
			if p != null:
				p.hold_to_move = not p.hold_to_move
		KEY_K:                       # set HP to 1 (test near-death / game over)
			var gs := _game_state()
			if gs != null:
				gs.set_hp(1)


func _build_text() -> String:
	var lines := PackedStringArray()
	lines.append("FPS %d" % Engine.get_frames_per_second())

	var gs := _game_state()
	if gs != null:
		lines.append("HP %d/%d   Lv.%d   XP %d/%d" % [
			gs.hp, gs.max_hp, gs.level, gs.xp, gs.xp_to_next()])

	var in_battle := get_tree().get_first_node_in_group("battle") != null
	lines.append("state: %s" % ("BATTLE" if in_battle else "overworld"))

	var p := _player()
	if p != null:
		lines.append("cell %s   moving:%s   hold:%s" % [p.grid_cell, p.is_moving, p.hold_to_move])
		if p.tile_map_layer != null:
			var td: TileData = p.tile_map_layer.get_cell_tile_data(p.grid_cell)
			if td != null:
				lines.append("tile  walkable:%s  monster:%s  boss:%s" % [
					td.get_custom_data("walkable"),
					td.get_custom_data("monster"),
					td.get_custom_data("boss")])

	lines.append("[F3] hide   [H] hold-move   [K] HP=1")
	return "\n".join(lines)


func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _game_state() -> Node:
	return get_node_or_null("/root/GameState")
