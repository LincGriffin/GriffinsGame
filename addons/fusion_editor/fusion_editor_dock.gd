@tool
class_name FusionEditorDock
extends VBoxContainer
## The fusion-editor dock UI — add / edit / delete monster-merge recipes (which parent pairs
## produce a specific named result, instead of a generic "Fused <parent>" blend) without
## hand-editing scripts/data/fusion_table.gd. A thin shell over FusionRepo (CRUD/validation,
## unit-tested headless in test_fusion_repo.gd) and MonsterRepo (Parent A/B/Result pickers). Built
## in code, no .tscn, matching monster_editor_dock.gd / powerup_editor_dock.gd.
##
## Unlike the Monster/Move/Power-up docks, a recipe's identity is its (sorted) parent pair, not a
## freely-typed id — so there's no "new_id" text field. "New" just clears the form; nothing is
## written until Save, once both parents and a result are picked.

const REPO := preload("res://scripts/data/fusion_repo.gd")
const MONSTER_REPO := preload("res://scripts/data/monster_repo.gd")
const FUSION_TABLE := preload("res://scripts/data/fusion_table.gd")

var _current: FusionRecipeData = null
var _current_original_id := ""   # "" means _current is new / not yet saved
var _loading := false

var _list: ItemList
var _list_ids: Array[String] = []   # parallel to _list — recipe id per row (list TEXT isn't the id)
var _status: Label
var _form: Control

var _parent_a_option: OptionButton
var _parent_b_option: OptionButton
var _result_option: OptionButton
var _preview: Label
var _delete_confirm: ConfirmationDialog


func _ready() -> void:
	name = "Fusions"
	custom_minimum_size = Vector2(280, 0)
	_build_ui()
	_refresh_list()
	_load_recipe(null)


func _build_ui() -> void:
	var hint := Label.new()
	hint.text = "Special monster-merge recipes — a parent pair here becomes a specific result instead of a generic blend."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)

	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(0, 140)
	_list.item_selected.connect(_on_list_item_selected)
	add_child(_list)

	var action_row := HBoxContainer.new()
	add_child(action_row)
	var new_btn := Button.new()
	new_btn.text = "New"
	new_btn.pressed.connect(_on_new_pressed)
	action_row.add_child(new_btn)
	var del_btn := Button.new()
	del_btn.text = "Delete"
	del_btn.pressed.connect(_on_delete_pressed)
	action_row.add_child(del_btn)

	add_child(HSeparator.new())

	_form = VBoxContainer.new()
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_form)

	_parent_a_option = _add_monster_field("Parent A")
	_parent_a_option.item_selected.connect(func(i):
		_set_field("parent_a", _parent_a_option.get_item_text(i)))
	_parent_b_option = _add_monster_field("Parent B")
	_parent_b_option.item_selected.connect(func(i):
		_set_field("parent_b", _parent_b_option.get_item_text(i)))
	_form.add_child(HSeparator.new())
	_result_option = _add_monster_field("Result")
	_result_option.item_selected.connect(func(i):
		_set_field("result_id", _result_option.get_item_text(i)))

	_preview = Label.new()
	_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview.add_theme_font_size_override("font_size", 16)
	_form.add_child(_preview)

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


func _add_monster_field(label: String) -> OptionButton:
	var row := HBoxContainer.new()
	_form.add_child(row)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(70, 0)
	row.add_child(l)
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(opt)
	return opt


## Repopulates all three monster dropdowns from disk — called every time the form is (re)loaded,
## not just once at dock startup, so a monster created via the Monsters dock earlier in the same
## editor session still shows up here (same gotcha/fix as monster_editor_dock.gd's move picker).
func _refresh_monster_options() -> void:
	for opt in [_parent_a_option, _parent_b_option, _result_option]:
		opt.clear()
		for id in MONSTER_REPO.list_ids():
			opt.add_item(id)


func _select_monster_option(opt: OptionButton, id: String) -> void:
	for i in opt.item_count:
		if opt.get_item_text(i) == id:
			opt.select(i)
			return
	opt.select(-1)   # no match (blank on a new recipe) — leave unselected rather than defaulting


## Mutate `_current` from a form control's signal, ignoring programmatic updates that happen
## while `_load_recipe` is populating the form (`_loading`).
func _set_field(field: String, value: String) -> void:
	if _current == null or _loading:
		return
	_current.set(field, value)
	_update_preview()


func _refresh_list() -> void:
	_list.clear()
	_list_ids.clear()
	for r in REPO.load_all():
		_list_ids.append(r.id)
		_list.add_item("%s + %s → %s" % [
			_display_name(r.parent_a), _display_name(r.parent_b), _display_name(r.result_id)])


func _display_name(id: String) -> String:
	if id.is_empty():
		return "?"
	var m := MONSTER_REPO.load_one(id)
	return m.display_name if m != null else id


func _on_list_item_selected(index: int) -> void:
	var id := _list_ids[index]
	_load_recipe(REPO.load_one(id))


## `r == null` clears the form (nothing selected / after a delete).
func _load_recipe(r: FusionRecipeData) -> void:
	_loading = true
	_current = r
	_current_original_id = "" if r == null else String(r.id)
	var enabled := r != null
	_form.visible = enabled
	_refresh_monster_options()
	if enabled:
		_select_monster_option(_parent_a_option, r.parent_a)
		_select_monster_option(_parent_b_option, r.parent_b)
		_select_monster_option(_result_option, r.result_id)
	_loading = false
	_update_preview()


func _update_preview() -> void:
	if _current == null:
		_preview.text = ""
		return
	if _current.parent_a.is_empty() or _current.parent_b.is_empty() or _current.result_id.is_empty():
		_preview.text = "Pick both parents and a result, then Save."
		return
	_preview.text = "→ %s + %s → %s" % [
		_display_name(_current.parent_a), _display_name(_current.parent_b), _display_name(_current.result_id)]


func _on_new_pressed() -> void:
	var script: GDScript = load("res://scripts/data/fusion_recipe_data.gd")
	_list.deselect_all()
	_load_recipe(script.new())
	_status.text = "New recipe — pick both parents and a result, then Save."


func _on_delete_pressed() -> void:
	if _current == null or _current_original_id.is_empty():
		_status.text = "Select a saved recipe to delete first."
		return
	_delete_confirm.dialog_text = "Delete the recipe for %s? This cannot be undone." % _preview.text.trim_prefix("→ ")
	_delete_confirm.popup_centered()


func _on_delete_confirmed() -> void:
	if _current == null:
		return
	var id := _current_original_id
	if REPO.delete(id):
		_status.text = "Deleted."
		FUSION_TABLE.clear_cache()
		_refresh_list()
		_load_recipe(null)
	else:
		_status.text = "Error: could not delete."


func _on_save_pressed() -> void:
	if _current == null:
		_status.text = "Nothing to save — click New or select a recipe first."
		return
	var result: Dictionary = REPO.save(_current, _current_original_id)
	if not result.ok:
		_status.text = "Error: " + result.error
		return
	_status.text = "Saved."
	FUSION_TABLE.clear_cache()
	_refresh_list()
	_select_id(_current.id)


func _select_id(id: String) -> void:
	var idx := _list_ids.find(id)
	if idx >= 0:
		_list.select(idx)
		_load_recipe(REPO.load_one(id))
