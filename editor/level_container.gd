extends Control
class_name LevelContainer
## Contains the level, centered, and at the correct aspect ratio
## Also is just the level editor for general input reasons (this should've been LevelContainerInner maybe but it's not that strong of a reason to clutter the responsibilities further)

@export var inner_container: Control
@export var gameplay: GameplayManager
#@onready var level: Level = gameplay.level
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
		return editor_data.hover_highlight

@export var camera_dragger: CameraDragger
@export var editor_camera: Camera2D

# Ghosts shouldn't be seen when something's being dragged

var is_dragging := false:
	get:
		if selected_obj == null or Input.is_action_pressed(&"unbound_action"):
			is_dragging = false
		return is_dragging
	set(val):
		is_dragging = val and selected_obj != null and not Input.is_action_pressed(&"unbound_action")
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

func _adjust_inner_container_dimensions() -> void:
	if editor_data.is_playing:
		inner_container.position = ((size - OBJ_SIZE) / 2).floor()
		inner_container.size = OBJ_SIZE
	else:
		inner_container.position = Vector2.ZERO
		inner_container.size = size

func _ready() -> void:
	gameplay.level.element_gui_input.connect(_on_element_gui_input)
	resized.connect(_adjust_inner_container_dimensions)
	level_viewport.get_parent().show()

func set_editor_data(data: EditorData) -> void:
	assert(editor_data == null, "This should only really run once.")
	editor_data = data
	editor_data.selected_highlight = selected_highlight
	editor_data.danger_highlight = danger_highlight
	editor_data.hover_highlight = gameplay.level.hover_highlight
	
	editor_data.side_tabs.tab_changed.connect(_retry_ghosts)
	editor_data.changed_level_data.connect(_on_changed_level_data)
	# deferred: fixes the door staying at the old mouse position (since the level pos moves when the editor kicks in)
	editor_data.changed_is_playing.connect(_on_changed_is_playing, CONNECT_DEFERRED)
	selected_highlight.adapted_to.connect(_on_selected_highlight_adapted_to)
	
	editor_camera.make_current()
	_on_changed_is_playing()
	_center_level.call_deferred()

func _on_changed_is_playing() -> void:
	_adjust_inner_container_dimensions()
	if not editor_data.is_playing:
		editor_camera.make_current()
	camera_dragger.enabled = not editor_data.is_playing
	_retry_ghosts()

# could be more sophisticated now that bigger level sizes are supported.
func _center_level() -> void:
	editor_camera.position = - (size - OBJ_SIZE) / 2

func _on_changed_level_data() -> void:
	# deselect everything
	selected_obj = null
	hovered_obj = null
	danger_obj = null

func _on_element_gui_input(event: InputEvent, node: Node, type: Enums.level_element_types) -> void:
	if editor_data.disable_editing: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				if remove_element(node):
					accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var editor_control = editor_data.level_element_editors[type]
				editor_control.data = node.data
				editor_data.side_tabs.set_current_tab_control(editor_control)
				accept_event()
				select_thing(node)
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and Input.is_action_pressed(&"unbound_action"):
			if remove_element(node):
				accept_event()


func _gui_input(event: InputEvent) -> void:
	if editor_data.disable_editing: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed: # mouse button released
				is_dragging = false
				return
			# TODO: What's the focus for??
			set_focus_mode(Control.FOCUS_ALL)
			grab_focus()
			# if the event got this far, we want to deselect
			selected_obj = null
			if editor_data.tilemap_edit:
				place_tile_on_mouse()
				accept_event()
				return
			if editor_data.level_elements:
				place_element_on_mouse(editor_data.level_element_type)
			elif editor_data.level_properties:
				if editor_data.player_spawn:
					place_player_spawn_on_mouse()
					accept_event()
				elif editor_data.goal_position:
					place_goal_on_mouse()
					accept_event()
			else:
				assert(false)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				selected_obj = null
				if remove_tile_on_mouse():
					accept_event()
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if selected_obj and is_dragging:
				relocate_selected()
			elif Input.is_action_pressed(&"unbound_action") and editor_data.level_elements:
				place_element_on_mouse(editor_data.level_element_type)
			elif editor_data.tilemap_edit:
				place_tile_on_mouse()
				accept_event()
			elif editor_data.level_properties:
				if editor_data.player_spawn:
					place_player_spawn_on_mouse()
					accept_event()
				elif editor_data.goal_position:
					place_goal_on_mouse()
					accept_event()
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
#			if editor_data.tilemap_edit:
				if remove_tile_on_mouse():
					accept_event()
		_retry_ghosts()

func select_thing(obj: Node) -> void:
	# is_dragging is set to true by _on_selected_highlight_adapted_to
	selected_obj = obj
	hovered_obj = obj
	danger_obj = null
	_retry_ghosts()

func place_tile_on_mouse() -> void:
	if editor_data.disable_editing: return
	if is_mouse_out_of_bounds(): return
	var coord := get_mouse_tile_coord(32)
	gameplay.level.place_tile(coord)

func remove_tile_on_mouse() -> bool:
	if editor_data.disable_editing: return false
	if is_mouse_out_of_bounds(): return false
	var coord := get_mouse_tile_coord(32)
	return gameplay.level.remove_tile(coord)

func place_element_on_mouse(type: Enums.level_element_types) -> bool:
	if editor_data.disable_editing: return false
	if is_mouse_out_of_bounds(): return false
	var coord := get_mouse_coord(LEVEL_ELEMENT_GRID_SIZE[type])
	var data = editor.level_element_editors[type].data.duplicated()
	data.position = coord
	var node := gameplay.level.add_element(data)
	if not is_instance_valid(node): return false
	select_thing(node)
	return true

func remove_element(node: Node) -> bool:
	if not is_instance_valid(node): return false
	gameplay.level.remove_element(node)
	select_thing(null)
	_retry_ghosts()
	return true

func place_player_spawn_on_mouse() -> void:
	if editor_data.disable_editing: return
	if is_mouse_out_of_bounds(): return
	var coord := get_mouse_coord(Vector2i(16, 16))
	gameplay.level.place_player_spawn(coord)

func place_goal_on_mouse() -> void:
	if editor_data.disable_editing: return
	if is_mouse_out_of_bounds(): return
	var coord := get_mouse_coord(Vector2i(16, 16))
	gameplay.level.place_goal(coord)

func relocate_selected() -> void:
	if editor_data.disable_editing: return
	if is_mouse_out_of_bounds(): return
	if not is_dragging: return
	if not is_instance_valid(selected_obj): return
	var type: Enums.level_element_types = selected_obj.level_element_type
	var grid_size: Vector2i = LEVEL_ELEMENT_GRID_SIZE[type]
	var used_coord := get_mouse_coord(grid_size) - round_coord(drag_offset, grid_size)
	var cond: bool
	var obj_pos: Vector2i = selected_obj.position
	cond = gameplay.level.move_element(selected_obj, selected_obj.level_element_type, used_coord)
	
	if not cond and obj_pos != used_coord:
		_place_danger_obj()
	else:
		danger_obj = null
	# refreshes the position
	selected_obj = selected_obj
	hovered_obj = hovered_obj



func get_mouse_coord(grid_size: Vector2i) -> Vector2i:
	return round_coord(Vector2i(get_global_mouse_position() - get_level_pos()), grid_size)

func get_mouse_tile_coord(grid_size: int) -> Vector2i:
	return round_coord(Vector2i(get_global_mouse_position() - get_level_pos()), Vector2i(grid_size, grid_size)) / grid_size

func round_coord(coord: Vector2i, grid_size: Vector2i) -> Vector2i:
	# wasn't sure how to do a "floor divide". this is crude but it works
	var val := coord.snapped(grid_size)
	if val.x > coord.x:
		val.x -= grid_size.x
	if val.y > coord.y:
		val.y -= grid_size.y
	return val

func is_mouse_out_of_bounds() -> bool:
	var local_pos := get_global_mouse_position() - get_level_pos()
	if local_pos.x < 0 or local_pos.y < 0 or local_pos.x >= gameplay.level.level_data.size.x or local_pos.y >= gameplay.level.level_data.size.y:
		return true
	return false

func get_level_pos() -> Vector2:
	return level_viewport.get_parent().global_position + gameplay.global_position - editor_camera.position
	#return level_viewport.get_parent().global_position + level.global_position - level.get_camera_position()

#var unique_queue := {}
#func _defer_unique(f: Callable) -> void:
#	if not unique_queue.get(f):
#		unique_queue[f] = true
#		f.call_deferred()
#		_erase_from_queue.bind(f).call_deferred()
#
#func _erase_from_queue(f: Callable) -> void:
#	unique_queue[f] = false


func _retry_ghosts() -> void:
	for ghost: Node in ghosts.values():
		ghost.hide()
	
	if not is_dragging:
		_place_ghosts()

const LEVEL_ELEMENT_GRID_SIZE := {
	Enums.level_element_types.door: Vector2i(32, 32),
	Enums.level_element_types.key: Vector2i(16, 16),
	Enums.level_element_types.entry: Vector2i(32, 32),
	Enums.level_element_types.salvage_point: Vector2i(16, 32),
}

func _place_ghosts() -> void:
	assert(not is_dragging)
	if not editor_data.level_elements or editor_data.is_playing:
		return
	var type := editor_data.level_element_type
	var grid_size: Vector2i = LEVEL_ELEMENT_GRID_SIZE[type]
	var obj: Node = ghosts[type]
	
	var editor_control: Control = editor_data.level_element_editors[type]
	obj.data = editor_control.data
	
	var maybe_pos := get_mouse_coord(grid_size)
	obj.position = maybe_pos
	obj.data.position = maybe_pos
	
	var is_valid := true
	
	if gameplay.level.is_space_occupied(Rect2i(maybe_pos, obj.get_rect().size)):
		is_valid = false
	elif obj is Door and not obj.data.check_valid(gameplay.level.level_data, false):
		is_valid = false
	obj.visible = is_valid
	
	if (
	not is_instance_valid(gameplay.level.hovering_over)
	and not obj.visible
	# TODO: This is just a double-check, but looks weird since tiles can't be hovered on yet
	#	and not level.is_space_occupied(Rect2i(get_mouse_coord(1), Vector2.ONE))
	):
		danger_obj = obj
	else:
		danger_obj = null

# places the danger obj only. this overrides the ghosts obvs
func _place_danger_obj() -> void:
	if not editor_data.level_elements or editor_data.is_playing:
		return
	var type := editor_data.level_element_type
	var grid_size: Vector2i = LEVEL_ELEMENT_GRID_SIZE[type]
	var obj: Node = ghosts[type]
	
	obj.data = editor_data.level_element_editors[type].data
		
	var maybe_pos := get_mouse_coord(grid_size)
	if is_dragging:
		maybe_pos -= round_coord(drag_offset, grid_size)
	obj.position = maybe_pos
	danger_obj = obj

func _on_selected_highlight_adapted_to(_obj: Node) -> void:
	if (Input.get_mouse_button_mask() & MOUSE_BUTTON_MASK_LEFT):
		if not is_dragging:
			is_dragging = true
			drag_offset = get_mouse_tile_coord(1) - Vector2i(_obj.position)
