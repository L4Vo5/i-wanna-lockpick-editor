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


@export var editor: LockpickEditor
var editor_data: EditorData: set = set_editor_data

#@export var danger_highlight: HoverHighlight
@export var selected_highlight: HoverHighlight
var hover_highlight: HoverHighlight:
	get:
		return level.hover_highlight

@onready var ghost_displayer: GhostDisplayer = %GhostDisplayer
@onready var selection_outline: SelectionOutline = %SelectionOutline
@onready var selection_box: Control = %SelectionBox
@onready var danger_outline: SelectionOutline = %DangerOutline

@onready var camera_dragger: NodeDragger = %CameraDragger
@onready var editor_camera: Camera2D = %EditorCamera

var drag_start := Vector2i.ZERO
var drag_state := None:
	set = set_drag_state
enum {
	None, Dragging, Selecting
}

var currently_adding: NewLevelElementInfo
# Key: collision system id (returned by level). Value: nothing
var selection := {}
var selection_grid_size := Vector2i.ONE


#var selection_system := SelectionSystem.new()

const OBJ_SIZE := Vector2(800, 608)
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
	
	#editor_data.side_tabs.tab_changed.connect(reset_multiple_selection)
	editor_data.side_tabs.tab_changed.connect(_update_preview)
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
	_update_preview()

# could be more sophisticated now that bigger level sizes are supported.
func _center_level() -> void:
	editor_camera.position = - (size - OBJ_SIZE) / 2

func _on_changed_level_data() -> void:
	pass
	#selection_system.level_container = self
	#selection_system.collision_system = editor_data.level_data.collision_system
	#selection_system.reset_selection()
	#selection_outline.reset()
	#selection_box.visible = false

func _input(event: InputEvent) -> void:
	# Don't wanna risk putting it in _gui_input and not receiving the event.
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			drag_state = None

func _gui_input(event: InputEvent) -> void:
	if editor_data.disable_editing: return
	#if editor_data.tab_is_multiple_selection:
		#_gui_input_multiple_selection(event)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: 
				if _handle_left_click():
					accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				if _handle_right_click():
					accept_event()
	elif event is InputEventMouseMotion:
		if _handle_mouse_movement():
			accept_event()
		_update_preview()

#var additional_selection: Dictionary = {}
#var did_toggle_selection: bool = false
#var toggle_selection_remove: bool = false
#var multi_drag: bool = false

#func _multiple_selection_grid_size() -> Vector2i:
	#var max_grid_size := GRID_SIZE
	#for id in selection_system.selection:
		#var data = editor_data.level_data.collision_system.get_rect_data(id)
		## if there's any tiles in the selection, grid size is 32,32
		#if data is Vector2i:
			#return Vector2i(32, 32)
	#return max_grid_size

#func reset_multiple_selection() -> void:
	#selection_system.reset_selection()
	#selection_outline.reset()
	#additional_selection.clear()

#func _gui_input_multiple_selection(event: InputEvent) -> void:
	#if event is InputEventMouseButton:
		#if event.button_index == MOUSE_BUTTON_LEFT:
			#selection_outline.color = Color.WHITE
			#if not event.pressed: # mouse button released
				#if multi_drag:
					#selection_outline.position += Vector2(selection_system.last_valid_offset - selection_system.offset)
				#selection_system.stop_moving()
				#if not multi_drag:
					#var rect := selection_box.get_rect()
					#var rects := collision_system.get_rects_intersecting_rect_in_grid(rect)
					#if did_toggle_selection and toggle_selection_remove:
						#selection_system.remove_multiple_from_selection(rects, selection_outline)
					#else:
						#selection_system.add_multiple_to_selection(rects, selection_outline)
					##for data in _get_additional_selectables():
						##var other_rect := _get_additional_selection_rect(data)
						##if other_rect.intersects(rect) and not additional_selection.has(data):
							##additional_selection[data] = true
							##selection_outline.add_rectangle_no_grid(other_rect, 1)
				#multi_drag = false
				#did_toggle_selection = false
				#selection_box.visible = false
				#return
			#var pos_in_level: Vector2i = get_mouse_tile_coord(1)
			#multi_drag = false
			#drag_start = pos_in_level
			#did_toggle_selection = false
			#selection_box.position = pos_in_level
			#selection_box.visible = false
			#selection_box.size = Vector2i.ZERO
			#if Input.is_key_pressed(KEY_SHIFT):
				## toggle selection
				#var rects := collision_system.get_rects_containing_point_in_grid(pos_in_level)
				#var action := 0
				#for id in rects:
					#if selection_system.selection.has(id):
						#if action == 0:
							#action = 1
						#if action == 1:
							#selection_system.remove_from_selection(id, selection_outline)
					#else:
						#if action == 0:
							#action = 2
						#if action == 2:
							#selection_system.add_to_selection(id, selection_outline)
				##for data in _get_additional_selectables():
					##var other_rect := _get_additional_selection_rect(data)
					##if other_rect.has_point(pos_in_level):
						##if additional_selection.has(data):
							##additional_selection.erase(data)
							##selection_outline.add_rectangle_no_grid(other_rect, -1)
						##else:
							##additional_selection[data] = true
							##selection_outline.add_rectangle_no_grid(other_rect, 1)
				#if action == 1:
					#did_toggle_selection = true
					#toggle_selection_remove = true
				#elif action == 2:
					#did_toggle_selection = true
					#toggle_selection_remove = false
				#return
			#elif not selection_system.selection.is_empty() or not additional_selection.is_empty():
				## Try to see whether we clicked on a selected item
				##for data in additional_selection:
					##var other_rect := _get_additional_selection_rect(data)
					##if other_rect.has_point(pos_in_level):
						##multi_drag = true
						##return
				#var rects := collision_system.get_rects_containing_point_in_grid(pos_in_level)
				#for id in rects:
					#if selection_system.selection.has(id):
						## clicked on selection
						#multi_drag = true
						#return
			#reset_multiple_selection()
	#elif event is InputEventMouseMotion:
		#if event.button_mask & MOUSE_BUTTON_LEFT:
			#if not multi_drag:
				#var rect := Rect2i()
				#rect.position = drag_start
				#rect.end = get_mouse_tile_coord(1)
				#rect = rect.abs()
				#selection_box.position = rect.position
				#selection_box.size = rect.size
				#selection_box.visible = true
			#else:
				#var grid_size := _multiple_selection_grid_size()
				#var new_offset := get_mouse_coord(grid_size) - round_coord(drag_start, grid_size)
				#var delta := new_offset - selection_system.offset
				#if delta == Vector2i.ZERO:
					#return
				#var act_delta := new_offset - selection_system.last_valid_offset
				##var valid := _can_move_additional_selection(act_delta)
				#var valid := true
				#if selection_system.move_selection(delta, valid):
					#_move_selection(act_delta)
					##_move_additional_selection(act_delta)
					#selection_outline.color = Color.WHITE
				#else:
					#selection_outline.color = Color.RED
				#selection_outline.position += Vector2(delta)

#func _move_selection(delta: Vector2i) -> void:
	#level.dont_update_collision_system = true
	#
	#var new_tile_id: Array[int] = []
	#var new_tile_pos: Array[Vector2i] = []
	#var new_tiles: Array[int] = []
	#for id in selection_system.selection:
		#var data = editor_data.level_data.collision_system.get_rect_data(id)
		#if data is Vector2i:
			## remove tile
			#var tile: int = editor_data.level_data.tiles[data]
			#level.remove_tile(data, false)
			#new_tile_id.push_back(id)
			#new_tile_pos.push_back(data + delta / 32)
			#new_tiles.push_back(tile)
		#elif data is RefCounted:
			## assume level element
			#var element: Control = level.original_data_to_element[data]
			#level.move_element(element, data.position + delta, false)
		#elif data == &"player_spawn":
			#editor_data.level_data.player_spawn_position += delta
		#elif data == &"goal":
			#editor_data.level_data.goal_position += delta
	#for tile_index in new_tile_pos.size():
		## add tile
		#var tile := new_tiles[tile_index]
		#var new_pos := new_tile_pos[tile_index]
		#editor_data.level_data.tiles[new_pos] = tile
		#level.update_tile_and_neighbors(new_pos)
		#editor_data.level_data.collision_system.set_rect_data(new_tile_id[tile_index], new_pos)
		#tile_index += 1
	#level.dont_update_collision_system = false
	#editor_data.level_data.emit_changed()

func _handle_left_click() -> bool:
	var handled := false
	# Clicked something? if not, try placing
	if Input.is_key_pressed(KEY_CTRL):
		drag_state = Selecting
		drag_start = level.get_local_mouse_position()
		if level.hovering_over != -1:
			add_to_selection(level.hovering_over)
		handled = true
	elif level.hovering_over != -1:
		if not level.hovering_over in selection:
			select_thing(level.hovering_over)
		drag_state = Dragging
		drag_start = level.get_local_mouse_position()
		handled = true
	else:
		handled = _try_place_curretly_adding()
	
	return handled

func _handle_right_click() -> bool:
	return _try_remove_at_mouse()

func _handle_mouse_movement() -> bool:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if drag_state == Selecting:
			expand_selection()
			return true
		if not selection.is_empty() and drag_state == Dragging:
			relocate_selection()
			return true
		elif Input.is_action_pressed(&"unbound_action") and editor_data.is_placing_level_element:
			return _try_place_curretly_adding()
		elif editor_data.tab_is_level_properties and (editor_data.is_placing_player_spawn or editor_data.is_placing_goal_position) or editor_data.tab_is_tilemap_edit:
			return _try_place_curretly_adding()
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if Input.is_action_pressed(&"unbound_action") and editor_data.is_placing_level_element:
			return _try_remove_at_mouse()
		elif editor_data.tab_is_tilemap_edit:
			return _try_remove_at_mouse()
	return false

func _try_place_curretly_adding() -> bool:
	# PERF: update when it actually changes, not here?
	_update_currently_adding()
	if not currently_adding:
		return false
	var id := level.add_element(currently_adding)
	if id != -1:
		select_thing(id)
		return true
	return false

func _try_remove_at_mouse() -> bool:
	var mouse_pos := level.get_local_mouse_position()
	if level.remove_at_pos(mouse_pos):
		_update_preview()
		return true
	return false

func _update_currently_adding() -> void:
	var info := NewLevelElementInfo.new()
	if editor_data.tab_is_tilemap_edit:
		info.type = Enums.LevelElementTypes.Tile
	elif editor_data.is_placing_level_element:
		info.type = editor_data.level_element_type
		info.data = editor.level_element_editors[info.type].data.duplicated()
	elif editor_data.tab_is_level_properties:
		if editor_data.is_placing_player_spawn:
			info.type = Enums.LevelElementTypes.PlayerSpawn
		elif editor_data.is_placing_goal_position:
			info.type = Enums.LevelElementTypes.Goal
		else:
			assert(false)
	else:
		info = null
	if info:
		var grid_size := LevelData.get_element_grid_size(info.type)
		var rect_size := info.get_rect().size
		var mouse_pos := level.get_local_mouse_position() as Vector2i
		var pos := mouse_pos - rect_size / 2
		info.position = pos.snapped(grid_size)
	
	currently_adding = info
	ghost_displayer.info = currently_adding
	if currently_adding and drag_state == None:
		danger_outline.clear()
		danger_outline.position = Vector2.ZERO
		danger_outline.add_rect(currently_adding.get_rect())

func clear_selection() -> void:
	selection.clear()
	selection_outline.clear()
	danger_outline.clear()
	selection_grid_size = Vector2i.ONE

func add_to_selection(id: int) -> void:
	selection[id] = true
	var rect := collision_system.get_rect(id)
	rect.position -= selection_outline.position as Vector2i
	selection_outline.add_rect(rect)
	var type := LevelData.get_element_type(collision_system.get_rect_data(id))
	var grid_size := LevelData.get_element_grid_size(type)
	selection_grid_size = Vector2i(
		maxi(selection_grid_size.x, grid_size.x),
		maxi(selection_grid_size.y, grid_size.y)
	)

func select_thing(id: int) -> void:
	# TODO: make optimized ig
	#selection.clear()
	#selection[id] = true
	clear_selection()
	add_to_selection(id)
	
	var elem = collision_system.get_rect_data(id)
	var type := LevelData.get_element_type(elem)
	if type in Enums.NODE_LEVEL_ELEMENTS:
		var editor_control = editor_data.level_element_editors[type]
		editor_control.data = elem.duplicated()
		editor_data.side_tabs.set_current_tab_control(editor_control)

#func select_thing(obj: Node) -> void:
	#if obj:
		#var type: Enums.LevelElementTypes = obj.level_element_type
		#var editor_control = editor_data.level_element_editors[type]
		#editor_control.data = obj.data.duplicated()
		#editor_data.side_tabs.set_current_tab_control(editor_control)
		#if not is_dragging:
			#is_dragging = true
			#drag_start = get_mouse_tile_coord(1) - Vector2i(obj.position)
	#selected_obj = obj
	#hovered_obj = obj
	#danger_obj = null
	#_update_preview()

func relocate_selection() -> void:
	if editor_data.disable_editing: return
	assert(drag_state == Dragging)
	assert(not selection.is_empty())
	drag_start = (drag_start / selection_grid_size) * selection_grid_size
	var mouse_pos := ((level.get_local_mouse_position() as Vector2i) / selection_grid_size) * selection_grid_size
	var relative_pos := mouse_pos - drag_start
	if level.move_elements(selection, relative_pos):
		drag_start = mouse_pos
		selection_outline.position += relative_pos as Vector2
		danger_outline.hide()
	else:
		danger_outline.show()
		danger_outline.position = selection_outline.position + (relative_pos as Vector2)
	#if is_mouse_out_of_bounds(): return
	#if not is_dragging: return
	#if not is_instance_valid(selected_obj): return
	#var used_coord := get_mouse_coord(GRID_SIZE) - round_coord(drag_start, GRID_SIZE)
	#var cond: bool
	#var obj_pos: Vector2i = selected_obj.position
	#cond = level.move_element(selected_obj, used_coord)
	#
	#if not cond and obj_pos != used_coord:
		#_place_danger_obj()
	#else:
		#danger_obj = null
	## refreshes the position
	#selected_highlight.update_line()
	#hover_highlight.update_line()

func expand_selection() -> void:
	var mouse_pos := level.get_local_mouse_position() as Vector2i
	var rect := Rect2i(mouse_pos, Vector2.ZERO)
	rect = rect.expand(drag_start)
	selection_box.position = rect.position
	selection_box.size = rect.size
	selection_box.show()
	var ids := collision_system.get_rects_intersecting_rect_in_grid(rect)
	for id in ids:
		if id not in selection:
			add_to_selection(id)
	

func set_drag_state(state: int) -> void:
	if drag_state == state: return
	drag_state = state
	selection_box.hide()
	if drag_state == None:
		danger_outline.clear()
		danger_outline.position = Vector2.ZERO
		danger_outline.add_rect(currently_adding.get_rect())
	elif drag_state == Dragging:
		danger_outline.mimic_other(selection_outline)
		danger_outline.hide()

# Updates the ghost and the danger preview
func _update_preview() -> void:
	# PERF: update when it actually changes, not here?
	_update_currently_adding()
	if drag_state != None: return
	if not currently_adding or is_instance_valid(level.hover_highlight.current_obj):
		ghost_displayer.hide()
		danger_outline.hide()
		return
	var rect := currently_adding.get_rect()
	if level.is_space_occupied(rect):
		ghost_displayer.hide()
		danger_outline.show()
	else:
		ghost_displayer.show()
		danger_outline.hide()

# places the danger obj only. this overrides the ghosts obvs
func _place_danger_obj() -> void:
	pass
	#if not editor_data.is_placing_level_element or editor_data.is_playing:
		#return
	#var type := editor_data.level_element_type
	#var obj: Node = ghosts[type]
	#
	#obj.data = editor_data.level_element_editors[type].data
		#
	#var maybe_pos := get_mouse_coord(GRID_SIZE)
	#if is_dragging:
		#maybe_pos -= round_coord(drag_start, GRID_SIZE)
	#obj.position = maybe_pos
	#danger_obj = obj
