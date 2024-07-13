extends Tree
class_name LevelList

var pack_data: LevelPackData:
	set(value):
		if pack_data == value: return
		_disconnect_pack_data()
		pack_data = value
		_connect_pack_data()

signal selected_level(level: int)

func _ready() -> void:
	# Create root
	create_item()
	hide_root = true
	hide_folding = true
	select_mode = Tree.SELECT_ROW
	scroll_horizontal_enabled = false
	scroll_vertical_enabled = true
	columns = 2
	set_column_expand(0, false)
	set_column_expand(1, true)
	item_selected.connect(_selected_item)

func _selected_item() -> void:
	selected_level.emit(get_selected().get_index() + 1)

func _disconnect_pack_data() -> void:
	if not is_instance_valid(pack_data): return
	pack_data.added_level.disconnect(_handle_level_added)
	pack_data.deleted_level.disconnect(_handle_level_deleted)
	pack_data.moved_level.disconnect(_handle_level_moved)
	pack_data.swapped_levels.disconnect(_handle_level_moved)

func _connect_pack_data() -> void:
	if not is_instance_valid(pack_data): return
	update_all()
	pack_data.added_level.connect(_handle_level_added)
	pack_data.deleted_level.connect(_handle_level_deleted)
	pack_data.moved_level.connect(_handle_level_moved)
	pack_data.swapped_levels.connect(_handle_level_moved)

func _handle_level_added(index: int) -> void:
	get_root().create_child(index)
	update_single(index)
	_update_level_numbers()

func _handle_level_deleted(index: int) -> void:
	get_root().remove_child(get_root().get_child(index))
	_update_level_numbers()

func _handle_level_moved(from: int, to: int) -> void:
	get_root().remove_child(get_root().get_child(from))
	get_root().create_child(to)
	update_single(to)
	_update_level_numbers()

func update_all() -> void:
	clear()
	create_item() # create root
	for lvl in pack_data.levels:
		var item := create_item()
		item.set_text(1, lvl.name)
	_update_level_numbers()
	update_selection()

func update_single(index: int) -> void:
	var item := get_root().get_child(index)
	item.set_text(1, pack_data.levels[index].name)

func update_selection() -> void:
	if pack_data.state_data:
		var my_selected := get_selected()
		if my_selected == null || my_selected.get_index() != pack_data.state_data.current_level:
			deselect_all()
			set_selected(get_root().get_child(pack_data.state_data.current_level), 0)
			scroll_to_item(get_selected())

func update_visibility(search_term: String) -> void:
	if search_term.is_empty():
		for child in get_root().get_children():
			child.visible = true
		return
	search_term = search_term.to_lower()
	for child in get_root().get_children():
		var text := child.get_text(1)
		child.visible = text.to_lower().contains(search_term)

func _update_level_numbers() -> void:
	for child in get_root().get_children():
		child.set_text(0, str(child.get_index() + 1))

func _get_drag_data(at_position: Vector2) -> TreeItem:
	return get_item_at_position(at_position)

func _can_drop_data(at_position: Vector2, data) -> bool:
	if not data is TreeItem or data.get_tree() != self:
		drop_mode_flags = DROP_MODE_DISABLED
		return false
	var section := get_drop_section_at_position(at_position)
	if section == 1 || section == -1:
		drop_mode_flags = DROP_MODE_INBETWEEN
		return true
	return false

func _drop_data(at_position: Vector2, data) -> void:
	var from_index = data.get_index()
	var section := get_drop_section_at_position(at_position)
	var target_index := get_item_at_position(at_position).get_index()
	if section == 1:
		target_index += 1
	if target_index > from_index:
		target_index -= 1
	pack_data.move_level(from_index, target_index) # will emit moved_level
	drop_mode_flags = DROP_MODE_DISABLED
