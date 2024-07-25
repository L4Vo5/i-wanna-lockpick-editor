extends Control
class_name LevelContainer
## Contains the level, centered, and at the correct aspect ratio
## Also is just the level editor for general input reasons (this should've been LevelContainerInner maybe but it's not that strong of a reason to clutter the responsibilities further)

@export var inner_container: Control
@export var gameplay: GameplayManager
@export var level_viewport: SubViewport

var door_editor: DoorEditor:
	get:
		return editor_data.door_editor
var key_editor: KeyEditor:
	get:
		return editor_data.key_editor
var entry_editor: EntryEditor:
	get:
		return editor_data.entry_editor
var salvage_point_editor: SalvagePointEditor:
	get:
		return editor_data.salvage_point_editor
var level: Level:
	get:
		return gameplay.level
var collision_system: CollisionSystem:
	get:
		return level.level_data.collision_system

@export var ghost_door: Door
@export var ghost_key: KeyElement
@export var ghost_entry: Entry
@export var ghost_salvage_point: SalvagePoint

@onready var ghosts: Dictionary = {
	Enums.level_element_types.door: ghost_door,
	Enums.level_element_types.key: ghost_key,
	Enums.level_element_types.entry: ghost_entry,
	Enums.level_element_types.salvage_point: ghost_salvage_point,
}

@export var editor: LockpickEditor
var editor_data: EditorData: set = set_editor_data

@export var danger_highlight: HoverHighlight
@export var selected_highlight: HoverHighlight
var hover_highlight: HoverHighlight:
	get:
		return level.hover_highlight

@export var selection_outline: SelectionOutline
@export var selection_box: Control

@onready var camera_dragger: NodeDragger = %CameraDragger
@onready var editor_camera: Camera2D = %EditorCamera

var is_dragging := false
var drag_offset := Vector2i.ZERO
var selected_obj: Node:
	set(val):
		selected_highlight.adapt_to(val)
	get:
		return selected_highlight.current_obj
var hovered_obj: Node:
	set(val):
		hover_highlight.adapt_to(val)
	get:
		return hover_highlight.current_obj
var danger_obj: Node:
	set(val):
		danger_highlight.adapt_to(val)
	get:
		return danger_highlight.current_obj
#var level_offset :=  Vector2(0, 0)

const OBJ_SIZE := Vector2(800, 608)

var selection_system := SelectionSystem.new()

func _adjust_inner_container_dimensions() -> void:
	if editor_data.is_playing:
		inner_container.position = ((size - OBJ_SIZE) / 2).floor()
		inner_container.size = OBJ_SIZE
	else:
		inner_container.position = Vector2.ZERO
		inner_container.size = size

func _ready() -> void:
	resized.connect(_adjust_inner_container_dimensions)

func set_editor_data(data: EditorData) -> void:
	assert(editor_data == null, "This should only really run once.")
	editor_data = data
	
	editor_data.side_tabs.tab_changed.connect(reset_multiple_selection)
	editor_data.side_tabs.tab_changed.connect(_update_ghosts)
	editor_data.changed_level_data.connect(_on_changed_level_data)
	_on_changed_level_data()
	# deferred: fixes the door staying at the old mouse position (since the level pos moves when the editor kicks in)
	editor_data.changed_is_playing.connect(_on_changed_is_playing, CONNECT_DEFERRED)
	
	editor_camera.make_current()
	_on_changed_is_playing()
	_center_level.call_deferred()

func _on_changed_is_playing() -> void:
	_adjust_inner_container_dimensions()
	if not editor_data.is_playing:
		editor_camera.make_current()
	camera_dragger.enabled = not editor_data.is_playing
	_update_ghosts()

# could be more sophisticated now that bigger level sizes are supported.
func _center_level() -> void:
	editor_camera.position = - (size - OBJ_SIZE) / 2

func _on_changed_level_data() -> void:
	# deselect everything
	selected_obj = null
	hovered_obj = null
	danger_obj = null
	selection_system.level_container = self
	selection_system.collision_system = editor_data.level_data.collision_system
	selection_system.reset_selection()
	selection_outline.reset()
	selection_box.visible = false

func _gui_input(event: InputEvent) -> void:
	if editor_data.disable_editing: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: 
				if _handle_left_click():
					accept_event()
			else:
				is_dragging = false
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				if _handle_right_click():
					accept_event()
	elif event is InputEventMouseMotion:
		if _handle_mouse_movement():
			accept_event()
		_update_ghosts()

var additional_selection: Dictionary = {}
var did_toggle_selection: bool = false
var toggle_selection_remove: bool = false
var multi_drag: bool = false

func _multiple_selection_grid_size() -> Vector2i:
	var max_grid_size := GRID_SIZE
	for id in selection_system.selection:
		var data = editor_data.level_data.collision_system.get_rect_data(id)
		# if there's any tiles in the selection, grid size is 32,32
		if data is Vector2i:
			return Vector2i(32, 32)
	return max_grid_size

func reset_multiple_selection() -> void:
	selection_system.reset_selection()
	selection_outline.reset()
	additional_selection.clear()

func _gui_input_multiple_selection(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			selection_outline.color = Color.WHITE
			if not event.pressed: # mouse button released
				if multi_drag:
					selection_outline.position += Vector2(selection_system.last_valid_offset - selection_system.offset)
				selection_system.stop_moving()
				if not multi_drag:
					var collision_system := editor_data.level_data.collision_system
					var rect := selection_box.get_rect()
					var rects := collision_system.get_rects_intersecting_rect_in_grid(rect)
					if did_toggle_selection and toggle_selection_remove:
						selection_system.remove_multiple_from_selection(rects, selection_outline)
					else:
						selection_system.add_multiple_to_selection(rects, selection_outline)
					#for data in _get_additional_selectables():
						#var other_rect := _get_additional_selection_rect(data)
						#if other_rect.intersects(rect) and not additional_selection.has(data):
							#additional_selection[data] = true
							#selection_outline.add_rectangle_no_grid(other_rect, 1)
				multi_drag = false
				did_toggle_selection = false
				selection_box.visible = false
				return
			var pos_in_level: Vector2i = get_mouse_tile_coord(1)
			multi_drag = false
			drag_offset = pos_in_level
			did_toggle_selection = false
			selection_box.position = pos_in_level
			selection_box.visible = false
			selection_box.size = Vector2i.ZERO
			if Input.is_key_pressed(KEY_SHIFT):
				# toggle selection
				var collision_system := editor_data.level_data.collision_system
				var rects := collision_system.get_rects_containing_point_in_grid(pos_in_level)
				var action := 0
				for id in rects:
					if selection_system.selection.has(id):
						if action == 0:
							action = 1
						if action == 1:
							selection_system.remove_from_selection(id, selection_outline)
					else:
						if action == 0:
							action = 2
						if action == 2:
							selection_system.add_to_selection(id, selection_outline)
				#for data in _get_additional_selectables():
					#var other_rect := _get_additional_selection_rect(data)
					#if other_rect.has_point(pos_in_level):
						#if additional_selection.has(data):
							#additional_selection.erase(data)
							#selection_outline.add_rectangle_no_grid(other_rect, -1)
						#else:
							#additional_selection[data] = true
							#selection_outline.add_rectangle_no_grid(other_rect, 1)
				if action == 1:
					did_toggle_selection = true
					toggle_selection_remove = true
				elif action == 2:
					did_toggle_selection = true
					toggle_selection_remove = false
				return
			elif not selection_system.selection.is_empty() or not additional_selection.is_empty():
				# Try to see whether we clicked on a selected item
				#for data in additional_selection:
					#var other_rect := _get_additional_selection_rect(data)
					#if other_rect.has_point(pos_in_level):
						#multi_drag = true
						#return
				var collision_system := editor_data.level_data.collision_system
				var rects := collision_system.get_rects_containing_point_in_grid(pos_in_level)
				for id in rects:
					if selection_system.selection.has(id):
						# clicked on selection
						multi_drag = true
						return
			reset_multiple_selection()
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_LEFT:
			if not multi_drag:
				var rect := Rect2i()
				rect.position = drag_offset
				rect.end = get_mouse_tile_coord(1)
				rect = rect.abs()
				selection_box.position = rect.position
				selection_box.size = rect.size
				selection_box.visible = true
			else:
				var grid_size := _multiple_selection_grid_size()
				var new_offset := get_mouse_coord(grid_size) - round_coord(drag_offset, grid_size)
				var delta := new_offset - selection_system.offset
				if delta == Vector2i.ZERO:
					return
				var act_delta := new_offset - selection_system.last_valid_offset
				#var valid := _can_move_additional_selection(act_delta)
				var valid := true
				if selection_system.move_selection(delta, valid):
					_move_selection(act_delta)
					#_move_additional_selection(act_delta)
					selection_outline.color = Color.WHITE
				else:
					selection_outline.color = Color.RED
				selection_outline.position += Vector2(delta)

func _move_selection(delta: Vector2i) -> void:
	level.dont_update_collision_system = true
	
	var new_tile_id: Array[int] = []
	var new_tile_pos: Array[Vector2i] = []
	var new_tiles: Array[int] = []
	for id in selection_system.selection:
		var data = editor_data.level_data.collision_system.get_rect_data(id)
		if data is Vector2i:
			# remove tile
			var tile: int = editor_data.level_data.tiles[data]
			level.remove_tile(data, false)
			new_tile_id.push_back(id)
			new_tile_pos.push_back(data + delta / 32)
			new_tiles.push_back(tile)
		elif data is RefCounted:
			# assume level element
			var element: Control = level.original_data_to_element[data]
			level.move_element(element, data.position + delta, false)
		elif data == &"player_spawn":
			editor_data.level_data.player_spawn_position += delta
		elif data == &"goal":
			editor_data.level_data.goal_position += delta
	for tile_index in new_tile_pos.size():
		# add tile
		var tile := new_tiles[tile_index]
		var new_pos := new_tile_pos[tile_index]
		editor_data.level_data.tiles[new_pos] = tile
		level.update_tile_and_neighbors(new_pos)
		editor_data.level_data.collision_system.set_rect_data(new_tile_id[tile_index], new_pos)
		tile_index += 1
	level.dont_update_collision_system = false
	editor_data.level_data.emit_changed()

func _handle_left_click() -> bool:
	# Clicked something? if not, try placing
	var mouse_pos := level.get_local_mouse_position()
	var obj = level.get_object_occupying(mouse_pos)
	if obj != null:
		select_thing(obj)
		return true
	else:
		return _try_place_at_mouse()

func _handle_right_click() -> bool:
	selected_obj = null
	return _try_remove_at_mouse()

func _handle_mouse_movement() -> bool:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if selected_obj and is_dragging:
			relocate_selected()
			return true
		elif Input.is_action_pressed(&"unbound_action") and editor_data.is_placing_level_element:
			return _try_place_at_mouse()
		elif editor_data.is_placing_player_spawn or editor_data.is_placing_goal_position or editor_data.tab_is_tilemap_edit:
			return _try_place_at_mouse()
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if remove_tile_on_mouse():
			accept_event()
		elif Input.is_action_pressed(&"unbound_action") and editor_data.is_placing_level_element:
			return _try_remove_at_mouse()
		elif editor_data.tab_is_tilemap_edit:
			return _try_remove_at_mouse()
	return false

func _try_place_at_mouse() -> bool:
	# TODO: What's the focus for??
	#set_focus_mode(Control.FOCUS_ALL)
	#grab_focus()
	# if the event got this far, we want to deselect
	selected_obj = null
	if editor_data.tab_is_tilemap_edit:
		return place_tile_on_mouse()
	if editor_data.is_placing_level_element:
		return place_element_on_mouse(editor_data.level_element_type)
	elif editor_data.tab_is_level_properties:
		if editor_data.is_placing_player_spawn:
			place_player_spawn_on_mouse()
			return true
		elif editor_data.is_placing_goal_position:
			place_goal_on_mouse()
			return true
	return false

func _try_remove_at_mouse() -> bool:
	if remove_tile_on_mouse():
		return true
	var mouse_pos := level.get_local_mouse_position()
	var obj = level.get_object_occupying(mouse_pos)
	if remove_element(obj):
		return true
	return false

func select_thing(obj: Node) -> void:
	if obj:
		var type: Enums.level_element_types = obj.level_element_type
		var editor_control = editor_data.level_element_editors[type]
		editor_control.data = obj.data.duplicated()
		editor_data.side_tabs.set_current_tab_control(editor_control)
		if not is_dragging:
			is_dragging = true
			drag_offset = get_mouse_tile_coord(1) - Vector2i(obj.position)
	selected_obj = obj
	hovered_obj = obj
	danger_obj = null
	_update_ghosts()

func place_tile_on_mouse() -> bool:
	if editor_data.disable_editing: return false
	if is_mouse_out_of_bounds(): return false
	var coord := get_mouse_tile_coord(32)
	return level.place_tile(coord)

func remove_tile_on_mouse() -> bool:
	if editor_data.disable_editing: return false
	if is_mouse_out_of_bounds(): return false
	var coord := get_mouse_tile_coord(32)
	return level.remove_tile(coord)

func place_element_on_mouse(type: Enums.level_element_types) -> bool:
	if editor_data.disable_editing: return false
	if is_mouse_out_of_bounds(): return false
	var coord := get_mouse_coord(GRID_SIZE)
	var data = editor.level_element_editors[type].data.duplicated()
	data.position = coord
	var node := level.add_element(data)
	if not is_instance_valid(node): return false
	select_thing(node)
	return true

func remove_element(node: Node) -> bool:
	if not is_instance_valid(node): return false
	level.remove_element(node)
	select_thing(null)
	_update_ghosts()
	return true

func place_player_spawn_on_mouse() -> void:
	if editor_data.disable_editing: return
	if is_mouse_out_of_bounds(): return
	var coord := get_mouse_coord(GRID_SIZE)
	level.place_player_spawn(coord)

func place_goal_on_mouse() -> void:
	if editor_data.disable_editing: return
	if is_mouse_out_of_bounds(): return
	var coord := get_mouse_coord(GRID_SIZE)
	level.place_goal(coord)

func relocate_selected() -> void:
	if editor_data.disable_editing: return
	if is_mouse_out_of_bounds(): return
	if not is_dragging: return
	if not is_instance_valid(selected_obj): return
	var used_coord := get_mouse_coord(GRID_SIZE) - round_coord(drag_offset, GRID_SIZE)
	var cond: bool
	var obj_pos: Vector2i = selected_obj.position
	cond = level.move_element(selected_obj, used_coord)
	
	if not cond and obj_pos != used_coord:
		_place_danger_obj()
	else:
		danger_obj = null
	# refreshes the position
	selected_highlight.update_line()
	hover_highlight.update_line()

func get_mouse_coord(grid_size: Vector2i) -> Vector2i:
	return round_coord(level.get_local_mouse_position(), grid_size)

func get_mouse_tile_coord(grid_size: int) -> Vector2i:
	return round_coord(level.get_local_mouse_position(), Vector2i(grid_size, grid_size)) / grid_size

func round_coord(coord: Vector2i, grid_size: Vector2i) -> Vector2i:
	# wasn't sure how to do a "floor divide". this is crude but it works
	var val := coord.snapped(grid_size)
	if val.x > coord.x:
		val.x -= grid_size.x
	if val.y > coord.y:
		val.y -= grid_size.y
	return val

func is_mouse_out_of_bounds() -> bool:
	var local_pos := level.get_local_mouse_position()
	if local_pos.x < 0 or local_pos.y < 0 or local_pos.x >= level.level_data.size.x or local_pos.y >= level.level_data.size.y:
		return true
	return false

const GRID_SIZE := Vector2i(16, 16)

func _update_ghosts() -> void:
	for ghost: Node in ghosts.values():
		ghost.hide()
	if not editor_data.is_placing_level_element or editor_data.is_playing:
		return
	var type := editor_data.level_element_type
	var grid_size: Vector2i = GRID_SIZE
	var obj: Node = ghosts[type]
	
	var editor_control: Control = editor_data.level_element_editors[type]
	obj.data = editor_control.data
	
	var maybe_pos := get_mouse_coord(grid_size)
	obj.position = maybe_pos
	obj.data.position = maybe_pos
	
	var is_valid := true
	
	if level.is_space_occupied(Rect2i(maybe_pos, obj.get_rect().size)):
		is_valid = false
	elif obj is Door and not obj.data.check_valid(level.level_data, false):
		is_valid = false
	obj.visible = is_valid
	
	if (
	not is_instance_valid(level.hovering_over)
	and not obj.visible
	# TODO: This is just a double-check, but looks weird since tiles can't be hovered on yet
	#	and not level.is_space_occupied(Rect2i(get_mouse_coord(1), Vector2.ONE))
	):
		danger_obj = obj
	else:
		danger_obj = null

# places the danger obj only. this overrides the ghosts obvs
func _place_danger_obj() -> void:
	if not editor_data.is_placing_level_element or editor_data.is_playing:
		return
	var type := editor_data.level_element_type
	var obj: Node = ghosts[type]
	
	obj.data = editor_data.level_element_editors[type].data
		
	var maybe_pos := get_mouse_coord(GRID_SIZE)
	if is_dragging:
		maybe_pos -= round_coord(drag_offset, GRID_SIZE)
	obj.position = maybe_pos
	danger_obj = obj
