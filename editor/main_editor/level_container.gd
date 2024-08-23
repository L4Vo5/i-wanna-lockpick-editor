extends Control
class_name LevelContainer
## Contains the level, centered, and at the correct aspect ratio
## Also is just the level editor for general input reasons (this should've been LevelContainerInner maybe but it's not that strong of a reason to clutter the responsibilities further)

@export var inner_container: Control
@export var gameplay: GameplayManager

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
		return level.collision_system


@export var editor: LockpickEditor
var editor_data: EditorData: set = set_editor_data

var hover_highlight: HoverHighlight:
	get:
		return level.hover_highlight

@onready var ghost_displayer: GhostDisplayer = %GhostDisplayer
@onready var selection_outline: SelectionOutline = %SelectionOutline
@onready var selection_box: Panel = %SelectionBox
@onready var danger_outline: SelectionOutline = %DangerOutline
@onready var phantom_grid: CanvasGroup = %PhantomGrid

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
	# (used only when playing the level)
	None,
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

# if true, tiles are overriding the tool so that it's brush instead of pencil
# this stops right click from mass-deleting non-tile elements, lets you
# click and drag the selection, and removes the grid effect
# crucially, this *won't* be true if you're on the brush tool because you're
# pressing shift.
var tiles_brush_override := false

var drag_start := Vector2i.ZERO
var drag_state := Drag.None
enum Drag { None = 0, Left, Right, Middle}

var new_selection_candidates := {} # idk how else to name it...
@export var expand_selection_style_box: StyleBox
@export var shrink_selection_style_box: StyleBox

var currently_adding: NewLevelElementInfo
# Key: collision system id (returned by level). Value: nothing
var selection := {}
var selection_grid_size := Vector2i.ONE
var grid_size_counts := {
	Vector2i(16, 16): 0,
	Vector2i(32, 32): 0,
}

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
	mouse_entered.connect(update_currently_adding)

func set_editor_data(data: EditorData) -> void:
	assert(editor_data == null, "This should only really run once.")
	editor_data = data
	
	editor_data.changed_side_editor_data.connect(update_currently_adding)
	editor_data.changed_level_data.connect(_on_changed_level_data)
	_on_changed_level_data()
	# deferred: fixes the door staying at the old mouse position (since the level pos moves when the editor kicks in)
	editor_data.changed_is_playing.connect(_on_changed_is_playing, CONNECT_DEFERRED)
	inner_container.resized.connect(clamp_editor_camera)
	
	editor_camera.make_current()
	_on_changed_is_playing()
	_center_level.call_deferred()

func _on_changed_is_playing() -> void:
	_adjust_inner_container_dimensions()
	if not editor_data.is_playing:
		editor_camera.make_current()
	_update_preview()
	decide_tool()
	# Fix for, idk, the camera? the Control nodes? the mouse position?
	# Not updating properly until next frame
	await get_tree().process_frame
	level.update_hover()

# could be more sophisticated now that bigger level sizes are supported.
func _center_level() -> void:
	editor_camera.position = - (size - OBJ_SIZE) / 2
	clamp_editor_camera()

func clamp_editor_camera() -> void:
	var min_pos := - inner_container.size
	var max_pos := level.level_data.size
	editor_camera.position = editor_camera.position.clamp(min_pos, max_pos)

# kept only for connections
var __level_data: LevelData
func _on_changed_level_data() -> void:
	if __level_data:
		__level_data.changed_size.disconnect(clamp_editor_camera)
	__level_data = level.level_data
	__level_data.changed_size.connect(clamp_editor_camera)
	clamp_editor_camera()
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
	if event.is_action_pressed(&"delete"):
		delete_selection()

func _gui_input(event: InputEvent) -> void:
	if editor_data.disable_editing: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed: 
			if _handle_left_click():
				accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if _handle_right_click():
				accept_event()
		elif event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			if _handle_middle_click():
				accept_event()
	elif event is InputEventMouseMotion:
		if _handle_mouse_movement():
			accept_event()

func _handle_left_click() -> bool:
	Global.release_gui_focus()
	var handled := false
	match current_tool:
		Tool.Pencil:
			if level.hovering_over != -1:
				select_thing(level.hovering_over)
				handled = true
			else:
				handled = _try_place_currently_adding()
				if not handled:
					clear_selection()
		Tool.Brush when tiles_brush_override and level.hovering_over != -1:
			select_thing(level.hovering_over)
			handled = true
			phantom_grid.hide()
		Tool.Brush:
			drag_start = currently_adding.position
			drag_state = Drag.Left
			handled = _try_place_currently_adding()
			phantom_grid.grid_size = currently_adding.get_rect().size
			phantom_grid.show()
			if tiles_brush_override:
				phantom_grid.hide()
			phantom_grid.offset = drag_start
			if handled:
				level.allow_hovering = false
			clear_selection()
		Tool.ModifySelection:
			if drag_state == Drag.Right:
				finish_expanding_selection()
			drag_start = level.get_local_mouse_position()
			drag_state = Drag.Left
			selection_box[&"theme_override_styles/panel"] = expand_selection_style_box
			expand_selection()
			handled = true
		Tool.DragLevel:
			if drag_state == Drag.None:
				drag_start = get_local_mouse_position()
				drag_state = Drag.Left
				handled = true
		Tool.DragSelection:
			# It's entered with left click and exited when it's released, thus this should never happen.
			assert(false)
		_:
			assert(false)
	return handled

func _handle_left_unclick() -> void:
	if is_instance_valid(level.goal):
		level.goal.stop_funny_animation()
	match current_tool:
		Tool.DragSelection:
			decide_tool()
	if drag_state == Drag.Left:
		match current_tool:
			Tool.ModifySelection:
				finish_expanding_selection()
			Tool.Brush:
				level.allow_hovering = true
				phantom_grid.hide()
		drag_state = Drag.None

func _handle_right_click() -> bool:
	Global.release_gui_focus()
	var handled := false
	match current_tool:
		Tool.Pencil:
			handled = _try_remove_at_mouse()
			if not handled:
				clear_selection()
		Tool.Brush:
			drag_state = Drag.Right
			handled = _try_remove_at_mouse()
			clear_selection()
		Tool.ModifySelection:
			if drag_state == Drag.Left:
				finish_expanding_selection()
			drag_start = level.get_local_mouse_position()
			drag_state = Drag.Right
			selection_box[&"theme_override_styles/panel"] = shrink_selection_style_box
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
	decide_tool()
	if current_tool == Tool.DragLevel:
		if drag_state == Drag.None:
			drag_state = Drag.Middle
			drag_start = get_local_mouse_position()
	return true

func _handle_middle_unclick() -> void:
	if drag_state == Drag.Middle:
		drag_state = Drag.None
	decide_tool()

func _handle_mouse_movement() -> bool:
	var handled := false
	match current_tool:
		Tool.Pencil:
			update_currently_adding_position()
			_update_preview()
		Tool.Brush:
			if currently_adding:
				if drag_state == Drag.Left:
					var grid_size := currently_adding.get_rect().size as Vector2
					var mouse_pos := level.get_local_mouse_position()
					var diff := mouse_pos - (drag_start as Vector2)
					diff = (diff / grid_size).floor() * grid_size
					drag_start += diff as Vector2i
					currently_adding.position = drag_start
					danger_outline.position = currently_adding.position
					_try_place_currently_adding()
				elif drag_state == Drag.Right:
					update_currently_adding_position()
					if not tiles_brush_override:
						_try_remove_at_mouse()
					else:
						if level.hovering_over != -1:
							var elem = collision_system.get_rect_data(level.hovering_over)
							var type := LevelData.get_element_type(elem)
							if type == Enums.LevelElementTypes.Tile:
								_try_remove_at_mouse()
				else:
					update_currently_adding_position()
				_update_preview()
		Tool.ModifySelection:
			if drag_state != Drag.None:
				expand_selection()
				handled = true
		Tool.DragSelection:
			if drag_state == Drag.Left:
				relocate_selection()
				handled = true
		Tool.DragLevel:
			if drag_state != Drag.None:
				assert(drag_state != Drag.Right)
				var new_pos := get_local_mouse_position() as Vector2i
				var offset := new_pos - drag_start
				drag_start = new_pos
				editor_camera.position -= offset as Vector2
				clamp_editor_camera()
	return handled

func _try_place_currently_adding() -> bool:
	if not currently_adding:
		return false
	if currently_adding.type in [Enums.LevelElementTypes.Goal, Enums.LevelElementTypes.PlayerSpawn]:
		remove_from_selection(level.elem_to_collision_system_id.get(currently_adding.type, -1))
	var id := level.add_element(currently_adding)
	if id != -1:
		if current_tool == Tool.Pencil:
			select_thing(id)
		return true
	return false

func _try_remove_at_mouse() -> bool:
	var mouse_pos := level.get_local_mouse_position()
	var id := level.get_visible_element_at_pos(mouse_pos)
	if id != -1:
		if id in selection:
			remove_from_selection(id)
		level.remove_element(id)
		_update_preview()
		return true
	return false

func delete_selection() -> void:
	for id in selection:
		level.remove_element(id)
	clear_selection()
	_update_preview()

func update_currently_adding() -> void:
	var info := NewLevelElementInfo.new()
	if editor_data.current_tab == editor_data.tile_editor:
		info.type = Enums.LevelElementTypes.Tile
	elif editor_data.current_tab is LevelPackPropertiesEditor:
		info.type = editor_data.current_tab.level_properties_editor.placing
	elif editor_data.current_tab.name in [&"Doors", &"Keys", &"Entries", &"SalvagePoints"]:
		info.type = editor_data.current_tab.data.level_element_type
		info.data = editor_data.current_tab.data.duplicated()
	else:
		info = null
	
	currently_adding = info
	ghost_displayer.info = currently_adding
	if currently_adding and current_tool in [Tool.Pencil, Tool.Brush]:
		danger_outline.clear()
		danger_outline.position = Vector2.ZERO
		danger_outline.add_rect(currently_adding.get_rect())
	update_currently_adding_position()

func update_currently_adding_position() -> void:
	if currently_adding:
		var grid_size := LevelData.get_element_grid_size(currently_adding.type)
		var rect_size := currently_adding.get_rect().size
		var mouse_pos := level.get_local_mouse_position() as Vector2i
		var pos := mouse_pos - rect_size / 2
		currently_adding.position = pos.snapped(grid_size)
		danger_outline.position = currently_adding.position

func clear_selection() -> void:
	selection.clear()
	selection_outline.clear()
	selection_grid_size = Vector2i.ONE
	for key in grid_size_counts:
		grid_size_counts[key] = 0

func add_to_selection(id: int) -> void:
	selection[id] = true
	var rect := collision_system.get_rect(id)
	rect.position -= selection_outline.position as Vector2i
	selection_outline.add_rect(rect)
	var type := LevelData.get_element_type(collision_system.get_rect_data(id))
	var grid_size := LevelData.get_element_grid_size(type)
	grid_size_counts[grid_size] += 1
	selection_grid_size = Vector2i(
		maxi(selection_grid_size.x, grid_size.x),
		maxi(selection_grid_size.y, grid_size.y)
	)

func remove_from_selection(id: int) -> void:
	if id == -1: return
	if not id in selection: return
	selection.erase(id)
	var rect := collision_system.get_rect(id)
	var type := LevelData.get_element_type(collision_system.get_rect_data(id))
	var grid_size := LevelData.get_element_grid_size(type)
	rect.position -= selection_outline.position as Vector2i
	selection_outline.remove_rect(rect)
	grid_size_counts[grid_size] -= 1
	assert(grid_size_counts[grid_size] >= 0)
	if grid_size_counts[grid_size] <= 0:
		if grid_size == Vector2i(32, 32):
			selection_grid_size = Vector2i(16, 16)
		# this is the fancy code if grid sizes aren't only 16,16 and 32,32
		#selection_grid_size = Vector2i.ONE
		#for possible_grid_size in grid_size_counts:
			#if grid_size_counts[possible_grid_size] <= 0: continue
			#selection_grid_size = Vector2i(
				#maxi(selection_grid_size.x, possible_grid_size.x),
				#maxi(selection_grid_size.y, possible_grid_size.y)
			#)

func select_thing(id: int) -> void:
	var elem = collision_system.get_rect_data(id)
	var type := LevelData.get_element_type(elem)
	if type == Enums.LevelElementTypes.Goal:
		level.goal.start_funny_animation()
	if id not in selection: 
		clear_selection()
		add_to_selection(id)
		current_tool = Tool.DragSelection
		if type in Enums.NODE_LEVEL_ELEMENTS:
			var editor_control = editor_data.level_element_editors[type]
			editor_control.data = elem.duplicated()
			editor_data.side_tabs.set_current_tab_control(editor_control)
			update_currently_adding()
	else:
		current_tool = Tool.DragSelection

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
	match drag_state:
		Drag.Left:
			for id in new_selection_candidates:
				if id not in ids:
					remove_from_selection(id)
			for id in ids:
				if id not in selection:
					new_selection_candidates[id] = true
					add_to_selection(id)
		Drag.Right:
			for id in new_selection_candidates:
				if id not in ids:
					add_to_selection(id)
			for id in ids:
				if id in selection:
					new_selection_candidates[id] = true
					remove_from_selection(id)
		Drag.None:
			assert(false)

func finish_expanding_selection() -> void:
	if drag_state == Drag.None: return
	selection_box.hide()
	new_selection_candidates.clear()

func set_tool(tool: Tool) -> void:
	if tool == current_tool: return
	# Exit previous tool
	ghost_displayer.hide()
	selection_box.hide()
	danger_outline.hide()
	phantom_grid.hide()
	if current_tool == Tool.None:
		selection_outline.show()
	
	current_tool = tool
	
	# Enter new tool
	match current_tool:
		Tool.None:
			selection_outline.hide()
		Tool.DragSelection:
			# Always entered from a left click.
			drag_state = Drag.Left
			drag_start = level.get_local_mouse_position()
			danger_outline.mimic_other(selection_outline)
			danger_outline.position = selection_outline.position
		Tool.Pencil, Tool.Brush:
			if currently_adding:
				currently_adding.position = Vector2i.ZERO
				danger_outline.clear()
				danger_outline.position = Vector2.ZERO
				danger_outline.add_rect(currently_adding.get_rect())
			update_currently_adding_position()
			_update_preview()
			if current_tool == Tool.Brush:
				if drag_state == Drag.Left and not tiles_brush_override:
					phantom_grid.show()
	level.allow_hovering = current_tool in [Tool.Pencil, Tool.Brush, Tool.None]

func decide_tool() -> void:
	tiles_brush_override = false
	if editor_data.is_playing:
		current_tool = Tool.None
	elif current_tool == Tool.DragSelection and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		pass # don't change it
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) or Input.is_key_pressed(KEY_ALT):
		current_tool = Tool.DragLevel
	elif Input.is_key_pressed(KEY_CTRL):
		current_tool = Tool.ModifySelection
	elif Input.is_key_pressed(KEY_SHIFT):
		current_tool = Tool.Brush
	elif currently_adding and currently_adding.type == Enums.LevelElementTypes.Tile:
		current_tool = Tool.Brush
		tiles_brush_override = true
	else:
		current_tool = Tool.Pencil
	# current_tool setter won't run if going between brush and override brush,
	# so I'll just do this manually here too
	if current_tool == Tool.Brush:
		if drag_state == Drag.Left and not tiles_brush_override:
			phantom_grid.show()
		else:
			phantom_grid.hide()

# Updates the ghost and the danger preview
func _update_preview() -> void:
	if current_tool == Tool.None or not currently_adding or (is_instance_valid(level.hover_highlight.current_obj) and level.allow_hovering):
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

func remove_goal() -> void:
	if not level.level_data.has_goal: return
	var id: int = level.elem_to_collision_system_id[Enums.LevelElementTypes.Goal]
	remove_from_selection(id)
	level.level_data.has_goal = false
