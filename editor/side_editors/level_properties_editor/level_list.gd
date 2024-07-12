extends Tree
class_name LevelList

var can_rearrange := true

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
	scroll_horizontal_enabled = true
	scroll_vertical_enabled = true
	columns = 1
	set_column_expand(0, true)
	item_selected.connect(_on_item_selected)

func _on_item_selected() -> void:
	selected_level.emit(get_selected().get_index() + 1)

func _disconnect_pack_data() -> void:
	if pack_data == null: return
	pack_data.added_level.disconnect(_handle_level_added)
	pack_data.deleted_level.disconnect(_handle_level_deleted)
	pack_data.moved_level.disconnect(_handle_level_moved)
	pack_data.swapped_levels.disconnect(_handle_level_moved)

func _connect_pack_data() -> void:
	if pack_data == null: return
	update_all()
	pack_data.added_level.connect(_handle_level_added)
	pack_data.deleted_level.connect(_handle_level_deleted)
	pack_data.moved_level.connect(_handle_level_moved)
	pack_data.swapped_levels.connect(_handle_level_moved)

func _handle_level_added(index: int) -> void:
	get_root().create_child(index)
	update_single(index)

func _handle_level_deleted(index: int) -> void:
	get_root().remove_child(get_root().get_child(index))

func _handle_level_moved(from: int, to: int) -> void:
	get_root().remove_child(get_root().get_child(from))
	get_root().create_child(to)
	update_single(to)

func update_all() -> void:
	clear()
	create_item() # create root
	for lvl in pack_data.levels:
		var item := create_item()
		item.set_text(0, get_level_string(lvl))

func update_single(index: int) -> void:
	var item := get_root().get_child(index)
	var lvl := pack_data.levels[index]
	item.set_text(0, get_level_string(lvl))

func set_selected_to(index: int) -> void:
	var item: TreeItem = get_root().get_child(index)
	if not item:
		breakpoint
	set_selected(item, 0)
	scroll_to_item(item)
	# fsr it doesn't update instantly if you don't tell it to
	queue_redraw()

func update_visibility(search_term: String) -> void:
	if search_term.is_empty():
		for child in get_root().get_children():
			child.visible = true
		return
	search_term = search_term.to_lower()
	for child in get_root().get_children():
		var text := child.get_text(0)
		child.visible = text.to_lower().contains(search_term)

func get_level_string(lvl: LevelData) -> String:
	var s := "Untitled"
	if lvl.name and lvl.title:
		s = "%s - %s" % [lvl.name, lvl.title]
	elif lvl.name:
		s = lvl.name
	elif lvl.title:
		s = lvl.tile
	if lvl.author:
		s += " (by %s)" % lvl.author
	return s

func _get_drag_data(at_position: Vector2) -> TreeItem:
	return get_item_at_position(at_position)

func _can_drop_data(at_position: Vector2, data) -> bool:
	if not can_rearrange:
		return false
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
