@tool
class_name PowerupEditorDock
extends VBoxContainer
## The power-up-editor dock UI — add / duplicate / edit / delete power-ups (and upload their
## portrait / sprite art) without hand-editing tools/gen_powerups.gd. A thin shell over
## PowerupRepo (CRUD/validation, unit-tested headless in test_powerup_repo.gd) and AssetLink
## (art import). Built in code, no .tscn, matching monster_editor_dock.gd.

const REPO := preload("res://scripts/data/powerup_repo.gd")
const MOVE_REPO := preload("res://scripts/data/move_repo.gd")
const POWERUP_ART := preload("res://scripts/data/powerup_art.gd")
const ASSET_LINK := preload("res://scripts/data/asset_link.gd")
const IMAGE_FILTER := "*.png,*.jpg,*.jpeg,*.webp"
const NO_MOVE := "(none)"

var _current: PowerupData = null
var _current_original_id := ""   # "" means _current is a new, not-yet-saved power-up
var _loading := false

var _list: ItemList
var _new_id_edit: LineEdit
var _status: Label
var _form: Control

var _id_edit: LineEdit
var _name_edit: LineEdit
var _effect_option: OptionButton
var _amount_spin: SpinBox
var _move_option: OptionButton
var _desc_edit: TextEdit
var _tint_picker: ColorPickerButton
var _delete_confirm: ConfirmationDialog

var _portrait_preview: TextureRect
var _sprite_preview: TextureRect
var _file_dialog: EditorFileDialog
var _pending_asset_target := ""   # "portrait" | "sprite"


func _ready() -> void:
	name = "Power-ups"
	custom_minimum_size = Vector2(280, 0)
	_build_ui()
	_refresh_list()
	_load_powerup(null)


func _build_ui() -> void:
	var new_row := HBoxContainer.new()
	add_child(new_row)
	_new_id_edit = LineEdit.new()
	_new_id_edit.placeholder_text = "new_powerup_id"
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

	var effect_row := HBoxContainer.new()
	_form.add_child(effect_row)
	effect_row.add_child(_label("Effect"))
	_effect_option = OptionButton.new()
	_effect_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for e in REPO.EFFECTS:
		_effect_option.add_item(e)
	_effect_option.item_selected.connect(func(i):
		_set_field("effect", _effect_option.get_item_text(i)))
	effect_row.add_child(_effect_option)

	_amount_spin = _add_spin_field("Amount", 0, 999)
	_amount_spin.value_changed.connect(func(v): _set_field("amount", int(v)))

	var move_row := HBoxContainer.new()
	_form.add_child(move_row)
	move_row.add_child(_label("Move"))
	_move_option = OptionButton.new()
	_move_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_move_option.add_item(NO_MOVE)
	for id in MOVE_REPO.list_ids():
		_move_option.add_item(id)
	_move_option.item_selected.connect(func(i):
		var text := _move_option.get_item_text(i)
		_set_field("move_id", "" if text == NO_MOVE else text))
	move_row.add_child(_move_option)
	var hint := Label.new()
	hint.text = "(Move is only used when Effect is \"move\".)"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_form.add_child(hint)

	_form.add_child(_label("Description"))
	_desc_edit = TextEdit.new()
	_desc_edit.custom_minimum_size = Vector2(0, 50)
	_desc_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_desc_edit.text_changed.connect(func(): _set_field("description", _desc_edit.text))
	_form.add_child(_desc_edit)

	var tint_row := HBoxContainer.new()
	_form.add_child(tint_row)
	tint_row.add_child(_label("Tint"))
	_tint_picker = ColorPickerButton.new()
	_tint_picker.custom_minimum_size = Vector2(60, 24)
	_tint_picker.color_changed.connect(func(c): _set_field("tint", c))
	tint_row.add_child(_tint_picker)

	_form.add_child(HSeparator.new())
	_form.add_child(_label("Art (optional)"))
	_portrait_preview = _add_art_row("Portrait", "portrait")
	_sprite_preview = _add_art_row("Sprite", "sprite")

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


## A "Portrait" or "Sprite" row: a preview thumbnail + Browse/Clear buttons.
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


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(70, 0)
	return l


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
	_load_powerup(REPO.load_one(id))
	_current_original_id = id


## `p == null` clears the form (nothing selected / after a delete).
func _load_powerup(p: PowerupData) -> void:
	_loading = true
	_current = p
	_current_original_id = "" if p == null else String(p.id)
	var enabled := p != null
	_form.visible = enabled
	if enabled:
		_id_edit.text = p.id
		_name_edit.text = p.display_name
		_select_option(_effect_option, p.effect)
		_amount_spin.value = p.amount
		_select_move(p.move_id)
		_desc_edit.text = p.description
		_tint_picker.color = p.tint
	_refresh_art_previews()
	_loading = false


func _select_option(opt: OptionButton, text: String) -> void:
	for i in opt.item_count:
		if opt.get_item_text(i) == text:
			opt.select(i)
			return
	opt.select(0)


func _select_move(move_id: String) -> void:
	if move_id.is_empty():
		_select_option(_move_option, NO_MOVE)
	else:
		_select_option(_move_option, move_id)


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
		_status.text = "Select a power-up to duplicate first."
		return
	var copy: PowerupData = _current.duplicate(true)
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
		_status.text = "Select a power-up to delete first."
		return
	_delete_confirm.dialog_text = "Delete power-up \"%s\"? This cannot be undone." % _current.id
	_delete_confirm.popup_centered()


func _on_delete_confirmed() -> void:
	if _current == null:
		return
	var id := _current_original_id
	if REPO.delete(id):
		_status.text = "Deleted \"%s\"." % id
		_refresh_list()
		_load_powerup(null)
	else:
		_status.text = "Error: could not delete \"%s\"." % id


func _on_save_pressed() -> void:
	if _current == null:
		_status.text = "Nothing to save — pick or create a power-up first."
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
			_load_powerup(REPO.load_one(id))
			return


# --- Art linking (portrait / sprite) ---

func _asset_dir(target: String) -> String:
	return POWERUP_ART.PORTRAIT_DIR if target == "portrait" else POWERUP_ART.SPRITE_DIR


func _on_browse_asset_pressed(target: String) -> void:
	if _current_original_id.is_empty():
		_status.text = "Save the power-up before assigning art (its id is the filename)."
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
	POWERUP_ART.clear_cache()
	_refresh_art_previews()
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()


func _on_clear_asset_pressed(target: String) -> void:
	if _current_original_id.is_empty():
		return
	if ASSET_LINK.clear_image(_asset_dir(target), _current_original_id):
		_status.text = "%s cleared for \"%s\"." % [target.capitalize(), _current_original_id]
		POWERUP_ART.clear_cache()
		_refresh_art_previews()


## Loads straight from disk (Image, not the resource-import pipeline) so a preview shows up
## immediately after Browse, without waiting on the editor's filesystem scan/reimport.
func _refresh_art_previews() -> void:
	if _portrait_preview == null:
		return
	_portrait_preview.texture = _load_preview("portrait")
	_sprite_preview.texture = _load_preview("sprite")


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
