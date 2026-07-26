@tool
class_name MoveEditorDock
extends VBoxContainer
## The move-editor dock UI — add / duplicate / edit / delete battle moves without hand-editing
## tools/gen_moves.gd. A thin shell over MoveRepo (which holds all the actual CRUD/validation
## logic and is unit-tested headless in test_move_repo.gd); this script only wires Controls to
## it. Built in code, no .tscn, matching the project's code-built-UI convention
## (starter_select.gd, monster_editor_dock.gd).

const REPO := preload("res://scripts/data/move_repo.gd")
const ASSET_LINK := preload("res://scripts/data/asset_link.gd")
const SFX_LIBRARY := preload("res://scripts/data/sfx_library.gd")
const VFX_LIBRARY := preload("res://scripts/data/vfx_library.gd")

const AUDIO_FILTER := "*.wav,*.ogg,*.mp3"
const SCENE_FILTER := "*.tscn,*.scn"

var _current: MoveData = null
var _current_original_id := ""   # "" means _current is a new, not-yet-saved move
var _loading := false

var _list: ItemList
var _new_id_edit: LineEdit
var _status: Label
var _form: Control

var _id_edit: LineEdit
var _name_edit: LineEdit
var _kind_option: OptionButton
var _power_spin: SpinBox
var _desc_edit: TextEdit
var _sfx_edit: LineEdit
var _vfx_edit: LineEdit
var _delete_confirm: ConfirmationDialog
var _file_dialog: EditorFileDialog
var _pending_effect_target := ""   # "sfx" | "vfx" — which field a Browse is filling


func _ready() -> void:
	name = "Moves"
	custom_minimum_size = Vector2(280, 0)
	_build_ui()
	_refresh_list()
	_load_move(null)


func _build_ui() -> void:
	var new_row := HBoxContainer.new()
	add_child(new_row)
	_new_id_edit = LineEdit.new()
	_new_id_edit.placeholder_text = "new_move_id"
	_new_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_row.add_child(_new_id_edit)
	var new_btn := Button.new()
	new_btn.text = "New"
	new_btn.pressed.connect(_on_new_pressed)
	new_row.add_child(new_btn)

	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(0, 160)
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

	var kind_row := HBoxContainer.new()
	_form.add_child(kind_row)
	kind_row.add_child(_label("Kind"))
	_kind_option = OptionButton.new()
	_kind_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in REPO.KINDS:
		_kind_option.add_item(k)
	_kind_option.item_selected.connect(func(i): _set_field("kind", _kind_option.get_item_text(i)))
	kind_row.add_child(_kind_option)

	_power_spin = _add_spin_field("Power", 0, 999)
	_power_spin.value_changed.connect(func(v): _set_field("power", int(v)))

	_form.add_child(_label("Description"))
	_desc_edit = TextEdit.new()
	_desc_edit.custom_minimum_size = Vector2(0, 60)
	_desc_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_desc_edit.text_changed.connect(func(): _set_field("description", _desc_edit.text))
	_form.add_child(_desc_edit)

	# Optional per-move effects (referenced by id, shareable across moves — see MoveData/battle.gd).
	# Each row: an id LineEdit + Browse that copies a picked file into the convention folder.
	_sfx_edit = _add_effect_row("SFX id", "sfx", AUDIO_FILTER)
	_sfx_edit.text_changed.connect(func(t): _set_field("sfx", t))
	_vfx_edit = _add_effect_row("VFX id", "vfx", SCENE_FILTER)
	_vfx_edit.text_changed.connect(func(t): _set_field("vfx", t))

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
	_file_dialog.file_selected.connect(_on_effect_file_selected)
	add_child(_file_dialog)


func _add_text_field(label: String) -> LineEdit:
	var row := HBoxContainer.new()
	_form.add_child(row)
	row.add_child(_label(label))
	var edit := LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	return edit


## An effect row: an id LineEdit + a Browse that copies a picked file into the effect's convention
## folder under the id typed in the field. `filter` is the file dialog's extension filter.
func _add_effect_row(label: String, target: String, filter: String) -> LineEdit:
	var row := HBoxContainer.new()
	_form.add_child(row)
	row.add_child(_label(label))
	var edit := LineEdit.new()
	edit.placeholder_text = "(none)"
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	var browse_btn := Button.new()
	browse_btn.text = "Browse..."
	browse_btn.pressed.connect(_on_effect_browse_pressed.bind(target, filter))
	row.add_child(browse_btn)
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


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(70, 0)
	return l


## Mutate `_current` from a form control's signal, ignoring the programmatic updates that happen
## while `_load_move` is populating the form (`_loading`).
func _set_field(field: String, value) -> void:
	if _current == null or _loading:
		return
	_current.set(field, value)


func _refresh_list() -> void:
	_list.clear()
	for id in REPO.list_ids():
		_list.add_item(id)


func _on_list_item_selected(index: int) -> void:
	var id := _list.get_item_text(index)
	_load_move(REPO.load_one(id))
	_current_original_id = id


## `mv == null` clears the form (nothing selected / after a delete).
func _load_move(mv: MoveData) -> void:
	_loading = true
	_current = mv
	_current_original_id = "" if mv == null else String(mv.id)
	var enabled := mv != null
	_form.visible = enabled
	if enabled:
		_id_edit.text = mv.id
		_name_edit.text = mv.display_name
		_select_kind(mv.kind)
		_power_spin.value = mv.power
		_desc_edit.text = mv.description
		_sfx_edit.text = mv.sfx
		_vfx_edit.text = mv.vfx
	_loading = false


func _select_kind(kind: String) -> void:
	for i in _kind_option.item_count:
		if _kind_option.get_item_text(i) == kind:
			_kind_option.select(i)
			return
	_kind_option.select(0)


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
		_status.text = "Select a move to duplicate first."
		return
	var copy: MoveData = _current.duplicate(true)
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
		_status.text = "Select a move to delete first."
		return
	_delete_confirm.dialog_text = "Delete move \"%s\"? This cannot be undone." % _current.id
	_delete_confirm.popup_centered()


func _on_delete_confirmed() -> void:
	if _current == null:
		return
	var id := _current_original_id
	if REPO.delete(id):
		_status.text = "Deleted \"%s\"." % id
		_refresh_list()
		_load_move(null)
	else:
		_status.text = "Error: could not delete \"%s\"." % id


func _on_save_pressed() -> void:
	if _current == null:
		_status.text = "Nothing to save — pick or create a move first."
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
			_load_move(REPO.load_one(id))
			return


# --- Effect linking (sfx / vfx) ---
# The destination filename is the id typed in the effect field (NOT the move id), so two moves can
# point at (share) the same effect. Blank = the move has no override (per-kind sound / no vfx).

func _effect_dir(target: String) -> String:
	return SFX_LIBRARY.DIR if target == "sfx" else VFX_LIBRARY.DIR


func _effect_id(target: String) -> String:
	return (_sfx_edit.text if target == "sfx" else _vfx_edit.text).strip_edges()


func _on_effect_browse_pressed(target: String, filter: String) -> void:
	if _effect_id(target).is_empty():
		_status.text = "Type a %s id first — it names the copied file." % target.to_upper()
		return
	_pending_effect_target = target
	_file_dialog.clear_filters()
	_file_dialog.add_filter(filter, "SFX" if target == "sfx" else "Effect scenes")
	_file_dialog.popup_centered_ratio(0.6)


func _on_effect_file_selected(path: String) -> void:
	var target := _pending_effect_target
	var id := _effect_id(target)
	var result: Dictionary = ASSET_LINK.import_file(path, _effect_dir(target), id)
	if not result.ok:
		_status.text = "Error: " + result.error
		return
	# Keep the field's id (import_file used it as the filename) and persist it on the move.
	_set_field(target, id)
	_status.text = "%s file set for id \"%s\"." % [target.to_upper(), id]
	SFX_LIBRARY.clear_cache()
	VFX_LIBRARY.clear_cache()
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
