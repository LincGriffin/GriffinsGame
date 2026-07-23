@tool
class_name MonsterEditorDock
extends VBoxContainer
## The monster-editor dock UI — add / duplicate / edit / delete monsters without hand-editing
## tools/gen_content.gd. A thin shell over MonsterRepo/MoveRepo (which hold all the actual
## CRUD/validation logic and are unit-tested headless in test_monster_repo.gd); this script
## only wires Controls to them. Built in code, no .tscn, matching the project's convention
## for code-built UI (starter_select.gd, title_screen.gd).

const REPO := preload("res://scripts/data/monster_repo.gd")
const MOVE_REPO := preload("res://scripts/data/move_repo.gd")
const MONSTER_DATA_SCRIPT := preload("res://scripts/data/monster_data.gd")
const PORTRAITS := preload("res://scripts/data/portraits.gd")
const MAP_SPRITES := preload("res://scripts/data/map_sprites.gd")
const ASSET_LINK := preload("res://scripts/data/asset_link.gd")
const IMAGE_FILTER := "*.png,*.jpg,*.jpeg,*.webp"

var _current: MonsterData = null
var _current_original_id := ""   # "" means _current is a new, not-yet-saved monster

var _list: ItemList
var _new_id_edit: LineEdit
var _status: Label
var _form: Control

var _id_edit: LineEdit
var _name_edit: LineEdit
var _hp_spin: SpinBox
var _atk_spin: SpinBox
var _def_spin: SpinBox
var _spd_spin: SpinBox
var _tier_spin: SpinBox
var _boss_check: CheckBox
var _starter_check: CheckBox
var _elite_check: CheckBox
var _tint_picker: ColorPickerButton
var _moves_list: ItemList
var _move_option: OptionButton
var _delete_confirm: ConfirmationDialog

var _portrait_preview: TextureRect
var _map_sprite_preview: TextureRect
var _file_dialog: EditorFileDialog
var _pending_asset_target := ""   # "portrait" | "map_sprite" — which Browse button opened the dialog


func _ready() -> void:
	name = "Monsters"
	custom_minimum_size = Vector2(280, 0)
	_build_ui()
	_refresh_list()
	_load_monster(null)


func _build_ui() -> void:
	var new_row := HBoxContainer.new()
	add_child(new_row)
	_new_id_edit = LineEdit.new()
	_new_id_edit.placeholder_text = "new_monster_id"
	_new_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_row.add_child(_new_id_edit)
	var new_btn := Button.new()
	new_btn.text = "New"
	new_btn.pressed.connect(_on_new_pressed)
	new_row.add_child(new_btn)

	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(0, 140)
	_list.item_selected.connect(_on_list_item_selected)
	add_child(_list)

	var action_row := HBoxContainer.new()
	add_child(action_row)
	var dup_btn := Button.new()
	dup_btn.text = "Duplicate"
	dup_btn.pressed.connect(_on_duplicate_pressed)
	action_row.add_child(dup_btn)
	var del_btn := Button.new()
	del_btn.text = "Delete"
	del_btn.pressed.connect(_on_delete_pressed)
	action_row.add_child(del_btn)

	add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_form = VBoxContainer.new()
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_form)

	_id_edit = _add_text_field("Id")
	_id_edit.text_changed.connect(func(t): _set_field("id", t))
	_name_edit = _add_text_field("Name")
	_name_edit.text_changed.connect(func(t): _set_field("display_name", t))

	_hp_spin = _add_spin_field("Max HP", 1, 999)
	_hp_spin.value_changed.connect(func(v): _set_field("max_hp", int(v)))
	_atk_spin = _add_spin_field("Attack", 0, 999)
	_atk_spin.value_changed.connect(func(v): _set_field("attack", int(v)))
	_def_spin = _add_spin_field("Defense", 0, 999)
	_def_spin.value_changed.connect(func(v): _set_field("defense", int(v)))
	_spd_spin = _add_spin_field("Speed", 0, 999)
	_spd_spin.value_changed.connect(func(v): _set_field("speed", int(v)))
	_tier_spin = _add_spin_field("Tier", 0, 4)
	_tier_spin.value_changed.connect(func(v): _set_field("tier", int(v)))

	_boss_check = _add_check_field("Boss")
	_boss_check.toggled.connect(func(p): _set_field("is_boss", p))
	_starter_check = _add_check_field("Starter")
	_starter_check.toggled.connect(func(p): _set_field("is_starter", p))
	_elite_check = _add_check_field("Elite")
	_elite_check.toggled.connect(func(p): _set_field("is_elite", p))

	var tint_row := HBoxContainer.new()
	_form.add_child(tint_row)
	tint_row.add_child(_label("Tint"))
	_tint_picker = ColorPickerButton.new()
	_tint_picker.custom_minimum_size = Vector2(60, 24)
	_tint_picker.color_changed.connect(func(c): _set_field("tint", c))
	tint_row.add_child(_tint_picker)

	_form.add_child(HSeparator.new())
	_form.add_child(_label("Moves"))
	_moves_list = ItemList.new()
	_moves_list.custom_minimum_size = Vector2(0, 90)
	_form.add_child(_moves_list)

	var move_row := HBoxContainer.new()
	_form.add_child(move_row)
	_move_option = OptionButton.new()
	_move_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id in MOVE_REPO.list_ids():
		_move_option.add_item(id)
	move_row.add_child(_move_option)
	var add_move_btn := Button.new()
	add_move_btn.text = "Add"
	add_move_btn.pressed.connect(_on_add_move_pressed)
	move_row.add_child(add_move_btn)
	var remove_move_btn := Button.new()
	remove_move_btn.text = "Remove Selected"
	remove_move_btn.pressed.connect(_on_remove_move_pressed)
	_form.add_child(remove_move_btn)

	_form.add_child(HSeparator.new())
	_form.add_child(_label("Art (optional)"))
	_portrait_preview = _add_art_row("Portrait", "portrait")
	_map_sprite_preview = _add_art_row("Map Sprite", "map_sprite")

	add_child(HSeparator.new())
	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(_on_save_pressed)
	add_child(save_btn)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)

	_delete_confirm = ConfirmationDialog.new()
	_delete_confirm.confirmed.connect(_on_delete_confirmed)
	add_child(_delete_confirm)

	_file_dialog = EditorFileDialog.new()
	_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	_file_dialog.add_filter(IMAGE_FILTER, "Images")
	_file_dialog.file_selected.connect(_on_asset_file_selected)
	add_child(_file_dialog)


## A "Portrait" or "Map Sprite" row: a preview thumbnail + Browse/Clear buttons. `target` is
## "portrait" or "map_sprite" — passed through to _on_browse_asset_pressed / _on_clear_asset_pressed.
func _add_art_row(label: String, target: String) -> TextureRect:
	var row := HBoxContainer.new()
	_form.add_child(row)
	row.add_child(_label(label))
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(64, 64)
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	row.add_child(preview)
	var col := VBoxContainer.new()
	row.add_child(col)
	var browse_btn := Button.new()
	browse_btn.text = "Browse..."
	browse_btn.pressed.connect(_on_browse_asset_pressed.bind(target))
	col.add_child(browse_btn)
	var clear_btn := Button.new()
	clear_btn.text = "Clear"
	clear_btn.pressed.connect(_on_clear_asset_pressed.bind(target))
	col.add_child(clear_btn)
	return preview


func _add_text_field(label: String) -> LineEdit:
	var row := HBoxContainer.new()
	_form.add_child(row)
	row.add_child(_label(label))
	var edit := LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	return edit


func _add_spin_field(label: String, min_v: int, max_v: int) -> SpinBox:
	var row := HBoxContainer.new()
	_form.add_child(row)
	row.add_child(_label(label))
	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spin)
	return spin


func _add_check_field(label: String) -> CheckBox:
	var check := CheckBox.new()
	check.text = label
	_form.add_child(check)
	return check


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(70, 0)
	return l


## Mutate `_current` from a form control's signal, ignoring the programmatic updates that
## happen while `_load_monster` is populating the form (`_loading`).
func _set_field(field: String, value) -> void:
	if _current == null or _loading:
		return
	_current.set(field, value)


var _loading := false


func _refresh_list() -> void:
	_list.clear()
	for id in REPO.list_ids():
		_list.add_item(id)


func _on_list_item_selected(index: int) -> void:
	var id := _list.get_item_text(index)
	_load_monster(REPO.load_one(id))
	_current_original_id = id


## `m == null` clears the form (nothing selected / after a delete).
func _load_monster(m: MonsterData) -> void:
	_loading = true
	_current = m
	_current_original_id = "" if m == null else String(m.id)
	var enabled := m != null
	_form.visible = enabled
	if enabled:
		_id_edit.text = m.id
		_name_edit.text = m.display_name
		_hp_spin.value = m.max_hp
		_atk_spin.value = m.attack
		_def_spin.value = m.defense
		_spd_spin.value = m.speed
		_tier_spin.value = m.tier
		_boss_check.button_pressed = m.is_boss
		_starter_check.button_pressed = m.is_starter
		_elite_check.button_pressed = m.is_elite
		_tint_picker.color = m.tint
		_refresh_moves_list()
	_refresh_art_previews()
	_loading = false


func _refresh_moves_list() -> void:
	_moves_list.clear()
	if _current == null:
		return
	for mv in _current.moves:
		_moves_list.add_item(String(mv.id))


func _on_new_pressed() -> void:
	var id := _new_id_edit.text.strip_edges()
	var result: Dictionary = REPO.create(id)
	if not result.ok:
		_status.text = "Error: " + result.error
		return
	_new_id_edit.text = ""
	_status.text = "Created \"%s\"." % id
	_refresh_list()
	_select_id(id)


func _on_duplicate_pressed() -> void:
	if _current == null:
		_status.text = "Select a monster to duplicate first."
		return
	var copy: MonsterData = _current.duplicate(true)
	var base_id: String = _current.id + "_copy"
	var candidate := base_id
	var n := 2
	while REPO.id_exists(candidate):
		candidate = "%s%d" % [base_id, n]
		n += 1
	copy.id = candidate
	var result: Dictionary = REPO.save(copy)
	if not result.ok:
		_status.text = "Error: " + result.error
		return
	_status.text = "Duplicated as \"%s\"." % candidate
	_refresh_list()
	_select_id(candidate)


func _on_delete_pressed() -> void:
	if _current == null:
		_status.text = "Select a monster to delete first."
		return
	_delete_confirm.dialog_text = "Delete monster \"%s\"? This cannot be undone." % _current.id
	_delete_confirm.popup_centered()


func _on_delete_confirmed() -> void:
	if _current == null:
		return
	var id := _current_original_id
	if REPO.delete(id):
		_status.text = "Deleted \"%s\"." % id
		_refresh_list()
		_load_monster(null)
	else:
		_status.text = "Error: could not delete \"%s\"." % id


func _on_add_move_pressed() -> void:
	if _current == null or _move_option.item_count == 0:
		return
	var id := _move_option.get_item_text(_move_option.selected)
	for mv in _current.moves:
		if mv.id == id:
			_status.text = "\"%s\" already knows %s." % [_current.id, id]
			return
	var mv := MOVE_REPO.load_all().filter(func(m): return m.id == id)
	if mv.is_empty():
		return
	_current.moves.append(mv[0])
	_refresh_moves_list()


func _on_remove_move_pressed() -> void:
	if _current == null:
		return
	var selected := _moves_list.get_selected_items()
	if selected.is_empty():
		return
	_current.moves.remove_at(selected[0])
	_refresh_moves_list()


func _on_save_pressed() -> void:
	if _current == null:
		_status.text = "Nothing to save — pick or create a monster first."
		return
	var result: Dictionary = REPO.save(_current, _current_original_id)
	if not result.ok:
		_status.text = "Error: " + result.error
		return
	_status.text = "Saved \"%s\"." % _current.id
	_current_original_id = _current.id
	_refresh_list()
	_select_id(_current.id)


func _select_id(id: String) -> void:
	for i in _list.item_count:
		if _list.get_item_text(i) == id:
			_list.select(i)
			_load_monster(REPO.load_one(id))
			return


# --- Art linking (portrait / map sprite) ---

func _asset_dir(target: String) -> String:
	return PORTRAITS.DIR if target == "portrait" else MAP_SPRITES.DIR


func _asset_preview(target: String) -> TextureRect:
	return _portrait_preview if target == "portrait" else _map_sprite_preview


func _on_browse_asset_pressed(target: String) -> void:
	if _current_original_id.is_empty():
		_status.text = "Save the monster before assigning art (its id is the filename)."
		return
	_pending_asset_target = target
	_file_dialog.popup_centered_ratio(0.6)


func _on_asset_file_selected(path: String) -> void:
	var target := _pending_asset_target
	var result: Dictionary = ASSET_LINK.import_image(path, _asset_dir(target), _current_original_id)
	if not result.ok:
		_status.text = "Error: " + result.error
		return
	_status.text = "%s set for \"%s\"." % [target.capitalize(), _current_original_id]
	_clear_asset_caches()
	_refresh_art_previews()
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()


func _on_clear_asset_pressed(target: String) -> void:
	if _current_original_id.is_empty():
		return
	if ASSET_LINK.clear_image(_asset_dir(target), _current_original_id):
		_status.text = "%s cleared for \"%s\"." % [target.capitalize(), _current_original_id]
		_clear_asset_caches()
		_refresh_art_previews()


func _clear_asset_caches() -> void:
	PORTRAITS.clear_cache()
	MAP_SPRITES.clear_cache()


## Loads straight from disk (Image, not the resource-import pipeline) so a preview shows up
## immediately after Browse, without waiting on the editor's filesystem scan/reimport.
func _refresh_art_previews() -> void:
	if _portrait_preview == null:
		return   # UI not built yet (first _load_monster call happens during _ready)
	_portrait_preview.texture = _load_preview("portrait")
	_map_sprite_preview.texture = _load_preview("map_sprite")


func _load_preview(target: String) -> Texture2D:
	if _current_original_id.is_empty():
		return null
	var path := _asset_dir(target) + _current_original_id + ".png"
	var global_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(global_path):
		return null
	var img := Image.load_from_file(global_path)
	if img == null:
		return null
	return ImageTexture.create_from_image(img)
