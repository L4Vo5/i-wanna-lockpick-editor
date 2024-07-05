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
	if pack_data == null: return
	pack_data.added_level.disconnect(_handle_level_added)
	pack_data.deleted_level.disconnect(_handle_level_deleted)
	pack_data.moved_level.disconnect(_handle_level_moved)
	pack_data.changed.disconnect(update_all)

func _connect_pack_data() -> void:
	if pack_data == null: return
	update_all()
	pack_data.added_level.connect(_handle_level_added)
	pack_data.deleted_level.connect(_handle_level_deleted)
	pack_data.moved_level.connect(_handle_level_moved)
	pack_data.changed.connect(update_all)

func _handle_level_added(_index: int) -> void:
	# TODO: Better solution
	update_all()

func _handle_level_deleted(_index: int) -> void:
	# TODO: Better solution
	update_all()

func _handle_level_moved(_from: int, _to: int) -> void:
	# TODO: Better solution
	update_all()

func update_all() -> void:
	clear()
	create_item() # create root
	for lvl in pack_data.levels:
		var item := create_item()
		item.set_text(1, lvl.name)
	_update_level_numbers()
	update_selected()

func update_selected() -> void:
	print("update")
	if pack_data.state_data:
		var my_selected := get_selected()
		if my_selected == null || my_selected.get_index() != pack_data.state_data.current_level:
			print("setting to ", pack_data.state_data.current_level)
			deselect_all()
			set_selected(get_root().get_child(pack_data.state_data.current_level), 0)

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

func _process(delta):
	get_local_mouse_position()
	pass
