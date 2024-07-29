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

var hover_highlight: HoverHighlight:
	get:
		return level.hover_highlight

@onready var ghost_displayer: GhostDisplayer = %GhostDisplayer
@onready var selection_outline: SelectionOutline = %SelectionOutline
@onready var selection_box: Control = %SelectionBox
@onready var danger_outline: SelectionOutline = %DangerOutline

@onready var editor_camera: Camera2D = %EditorCamera

# "Tool" system not shown to the user (yet?) but serves as an FSM.
# I'll describe the system here, for lack of a proper design document

# Input relevant for tools: Ctrl, Shift, Alt, Mouse Wheel pressed. Left/Right click. Mouse motion.
# In order of priority:
# Left Clicked on selection while on Pencil: DragSelection until click is released, ignoring all other input.
# Alt or Mouse Wheel: DragLevel
# Ctrl: ModifySelection
# Shift: Brush
# Otherwise: Pencil

# Other considerations:
# Ghost: Only shown on Pencil
# Danger outline: Only shown on Pencil, Brush, and DragSelection
# Selection outline: Shown whenver there's a selection.
# Hover outline / Mouseover text: only on Pencil?
# TODO:
# Ctrl+C / Ctrl+X: Copy/Cut, only if there's a valid selection. Sets ghosts to the selection.
# Ctrl+V: Sets ghosts back to the previous copied thing.

var current_tool := Tool.Pencil:
	set = set_tool

enum Tool {
	# Left click: place and select, or just select if can't place (overriding previous selection). If something selected, transitions to DragSelection. Right click: remove under mouse. If nothing to remove, clear selection.
	Pencil,
	# Left click: place (even with mouse movement). Right click: remove (even with mouse movement).
	Brush,
	# Left click + drag: add to selection in a rectangle. Right click + drag: remove to selection in a rectangle. (if you don't drag they still apply only to whatever's under the mouse)
	ModifySelection,
	# (Alt+Left click) or (Mouse wheel click) + mouse motion: drag the level around
	DragLevel, 
	# Moving the mouse moves the selection (clicking enters/exits the state)
	DragSelection,
}

var drag_start := Vector2i.ZERO
var drag_state := Drag.None
enum Drag { None = 0, Left, Right }

var new_selection_candidates := {} # idk how else to name it...

var currently_adding: NewLevelElementInfo
# Key: collision system id (returned by level). Value: nothing
var selection := {}
var selection_grid_size := Vector2i.ONE

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
	
	editor_data.changed_side_editor_data.connect(update_currently_adding)
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
	_update_preview()

# could be more sophisticated now that bigger level sizes are supported.
func _center_level() -> void:
	editor_camera.position = - (size - OBJ_SIZE) / 2

func _on_changed_level_data() -> void:
	pass
	# TODO: figure out what goes here
	#selection_system.level_container = self
	#selection_system.collision_system = editor_data.level_data.collision_system
	#selection_system.reset_selection()
	#selection_outline.reset()
	#selection_box.visible = false

func _input(event: InputEvent) -> void:
	# Don't wanna risk putting these in _gui_input and not receiving the event.
	decide_tool()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_handle_left_unclick()
		if event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
			_handle_right_unclick()
		if event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
			_handle_middle_unclick()

func _gui_input(event: InputEvent) -> void:
	if editor_data.disable_editing: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed: 
			if _handle_left_click():
				accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if _handle_right_click():
				accept_event()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if _handle_middle_click():
				accept_event()
	elif event is InputEventMouseMotion:
		if _handle_mouse_movement():
			accept_event()

func _handle_left_click() -> bool:
	var handled := false
	match current_tool:
		Tool.Pencil:
			if level.hovering_over != -1:
				select_thing(level.hovering_over)
				handled = true
			else:
				handled = _try_place_curretly_adding()
				if not handled:
					clear_selection()
		Tool.Brush:
			drag_start = level.get_local_mouse_position()
			drag_state = Drag.Left
			handled = _try_place_curretly_adding()
		Tool.ModifySelection:
			if drag_state == Drag.Right:
				finish_expanding_selection()
			drag_start = level.get_local_mouse_position()
			drag_state = Drag.Left
			expand_selection()
			handled = true
		Tool.DragLevel:
			drag_start = level.get_local_mouse_position()
			drag_state = Drag.Left
			handled = true
		Tool.DragSelection:
			# It's entered with left click and exited when it's released, thus this should never happen.
			assert(false)
		_:
			assert(false)
	return handled

func _handle_left_unclick() -> void:
	match current_tool:
		Tool.DragSelection:
			decide_tool()
	if drag_state == Drag.Left:
		match current_tool:
			Tool.ModifySelection:
				finish_expanding_selection()
		drag_state = Drag.None

func _handle_right_click() -> bool:
	var handled := false
	match current_tool:
		Tool.Pencil:
			handled = _try_remove_at_mouse()
			if not handled:
				clear_selection()
		Tool.Brush:
			drag_start = level.get_local_mouse_position()
			drag_state = Drag.Right
			handled = _try_place_curretly_adding()
		Tool.ModifySelection:
			if drag_state == Drag.Left:
				finish_expanding_selection()
			drag_start = level.get_local_mouse_position()
			drag_state = Drag.Right
			expand_selection()
			handled = true
	return handled

func _handle_right_unclick() -> void:
	if drag_state == Drag.Right:
		match current_tool:
			Tool.ModifySelection:
				finish_expanding_selection()
		drag_state = Drag.None

func _handle_middle_click() -> bool:
	return false

func _handle_middle_unclick() -> void:
	pass

func _handle_mouse_movement() -> bool:
	var handled := false
	match current_tool:
		Tool.ModifySelection:
			if drag_state != Drag.None:
				expand_selection()
				handled = true
		Tool.DragSelection:
			if drag_state == Drag.Left:
				relocate_selection()
				handled = true
		Tool.DragLevel:
			assert(false)
	#if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		#if drag_state == Selecting:
			#expand_selection()
			#return true
		#if not selection.is_empty() and drag_state == Dragging:
			#relocate_selection()
			#return true
		#elif Input.is_action_pressed(&"unbound_action") and editor_data.is_placing_level_element:
			#return _try_place_curretly_adding()
		#elif editor_data.tab_is_level_properties and (editor_data.is_placing_player_spawn or editor_data.is_placing_goal_position) or editor_data.tab_is_tilemap_edit:
			#return _try_place_curretly_adding()
	#if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		#if Input.is_action_pressed(&"unbound_action") and editor_data.is_placing_level_element:
			#return _try_remove_at_mouse()
		#elif editor_data.tab_is_tilemap_edit:
			#return _try_remove_at_mouse()
	return handled

func _try_place_curretly_adding() -> bool:
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

func update_currently_adding() -> void:
	var info := NewLevelElementInfo.new()
	if editor_data.current_tab.name == &"Tiles":
		info.type = Enums.LevelElementTypes.Tile
	elif editor_data.current_tab.name == &"LevelPack":
		info.type = editor_data.current_tab.placing
	elif editor_data.current_tab.name in [&"Doors", &"Keys", &"Entries", &"SalvagePoints"]:
		info.type = editor_data.current_tab.data.level_element_type
		info.data = editor_data.current_tab.data.duplicated()
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
	if currently_adding:
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

func remove_from_selection(id: int) -> void:
	selection.erase(id)
	var rect := collision_system.get_rect(id)
	selection_outline.remove_rect(rect)
	# TODO: This won't update selection_grid_size...

func select_thing(id: int) -> void:
	# TODO: make optimized ig
	#selection.clear()
	#selection[id] = true
	clear_selection()
	add_to_selection(id)
	current_tool = Tool.DragSelection
	
	var elem = collision_system.get_rect_data(id)
	var type := LevelData.get_element_type(elem)
	if type in Enums.NODE_LEVEL_ELEMENTS:
		var editor_control = editor_data.level_element_editors[type]
		editor_control.data = elem.duplicated()
		editor_data.side_tabs.set_current_tab_control(editor_control)

func relocate_selection() -> void:
	if editor_data.disable_editing: return
	assert(current_tool == Tool.DragSelection)
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

func expand_selection() -> void:
	var mouse_pos := level.get_local_mouse_position() as Vector2i
	var rect := Rect2i(mouse_pos, Vector2.ZERO)
	rect = rect.expand(drag_start)
	selection_box.position = rect.position
	selection_box.size = rect.size
	selection_box.show()
	var ids := collision_system.get_rects_intersecting_rect_in_grid(rect)
	for id in new_selection_candidates:
		if id not in ids:
			remove_from_selection(id)
	for id in ids:
		if id not in selection:
			new_selection_candidates[id] = true
			add_to_selection(id)

func finish_expanding_selection() -> void:
	if drag_state == Drag.None: return
	selection_box.hide()
	new_selection_candidates.clear()

func set_tool(tool: Tool) -> void:
	if tool == current_tool: return
	# Exit previous tool
	ghost_displayer.hide()
	selection_box.hide()
	
	current_tool = tool
	
	# Enter new tool
	match current_tool:
		Tool.DragSelection:
			# Always entered from a left click.
			drag_state = Drag.Left
			drag_start = level.get_local_mouse_position()
			danger_outline.mimic_other(selection_outline)
	level.allow_hovering = current_tool == Tool.Pencil

func decide_tool() -> void:
	if current_tool == Tool.DragSelection and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		pass # don't change it
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) or Input.is_key_pressed(KEY_ALT):
		current_tool = Tool.DragLevel
	elif Input.is_key_pressed(KEY_CTRL):
		current_tool = Tool.ModifySelection
	elif Input.is_key_pressed(KEY_SHIFT):
		current_tool = Tool.Brush
	else:
		current_tool = Tool.Pencil

#func set_drag_state(state: int) -> void:
	#if state == None and Input.is_key_pressed(KEY_CTRL):
		#state = CtrlHeld
	#if drag_state == state: return
	#drag_state = state
	#selection_box.hide()
	#match drag_state:
		#None:
			#danger_outline.clear()
			#danger_outline.position = Vector2.ZERO
			#danger_outline.add_rect(currently_adding.get_rect())
		#Dragging:
			#danger_outline.mimic_other(selection_outline)
			#danger_outline.hide()
	#_update_preview()

# Updates the ghost and the danger preview
func _update_preview() -> void:
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
