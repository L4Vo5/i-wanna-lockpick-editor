@tool
extends Tree
class_name LevelList

@export var can_rearrange := true

var pack_data: LevelPackData:
	set(value):
		if pack_data == value: return
		_disconnect_pack_data()
		pack_data = value
		_connect_pack_data()

signal selected_level(level_index: int)

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
	selected_level.emit(get_selected().get_index())

func _disconnect_pack_data() -> void:
	if not is_instance_valid(pack_data): return
	pack_data.added_level.disconnect(_handle_level_added)
	pack_data.deleted_level.disconnect(_handle_level_deleted)
	pack_data.moved_level.disconnect(_handle_level_moved)
	pack_data.swapped_levels.disconnect(_handle_level_moved)
	for item in get_root().get_children():
		_disconnect_item_from_lvl(item)

func _connect_pack_data() -> void:
	if not is_instance_valid(pack_data): return
	update_all()
	pack_data.added_level.connect(_handle_level_added)
	pack_data.deleted_level.connect(_handle_level_deleted)
	pack_data.moved_level.connect(_handle_level_moved)
	pack_data.swapped_levels.connect(_handle_level_moved)

func _handle_level_added(id: int) -> void:
	var index := pack_data.get_level_position_by_id(id)
	var item := get_root().create_child(index)
	_connect_item_to_lvl(item, pack_data.get_level_by_position(index))

func _handle_level_deleted(_id: int, index: int) -> void:
	var item := get_root().get_child(index)
	get_root().remove_child(item)
	_disconnect_item_from_lvl(item)

func _handle_level_moved(from: int, to: int) -> void:
	var old_item := get_root().get_child(from)
	get_root().remove_child(old_item)
	_disconnect_item_from_lvl(old_item)
	var new_item := get_root().create_child(to)
	_connect_item_to_lvl(new_item, pack_data.get_level_by_position(to))

func update_all() -> void:
	clear()
	create_item() # create root
	for i in pack_data.levels.size():
		var lvl := pack_data.get_level_by_position(i)
		var item := create_item()
		_connect_item_to_lvl(item, lvl)

func _connect_item_to_lvl(item: TreeItem, level: LevelData) -> void:
	assert(item.get_metadata(0) == null)
	item.set_metadata(0, level)
	level.changed.connect(_update_item.bind(item, level))
	_update_item(item, level)

func _disconnect_item_from_lvl(item: TreeItem) -> void:
	var level: LevelData = item.get_metadata(0)
	level.changed.disconnect(_update_item.bind(item, level))
	item.set_metadata(0, null)

func _update_item(item: TreeItem, level: LevelData) -> void:
	item.set_text(0, get_level_string(level))

func set_selected_to(id: int) -> void:
	var index := pack_data.level_order.find(id)
	assert(index != -1)
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
		s = "%s - %s" % [lvl.title, lvl.name]
	elif lvl.name:
		s = lvl.name
	elif lvl.title:
		s = lvl.title
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
	if section == 1 or section == -1:
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
