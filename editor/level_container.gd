extends Control
class_name LevelContainer
## Contains the level, centered, and at the correct aspect ratio
## Also is just the level editor for general input reasons (this should've been LevelContainerInner maybe but it's not that strong of a reason to clutter the responsibilities further)

@export var inner_container: Control
@export var level: Level
@export var level_viewport: SubViewport

@export var tile_map: TileMap
@export var door_editor: DoorEditor
@export var key_editor: KeyEditor

@export var ghost_door: Door
@export var ghost_key: Key
@export var ghost_canvas_group: CanvasGroup

@export var editor: LockpickEditor
var editor_data: EditorData

@export var danger_highlight: HoverHighlight
@export var selected_highlight: HoverHighlight
var hover_highlight: HoverHighlight:
	get:
		return editor_data.hover_highlight

#var level_offset :=  Vector2(0, 0)

const OBJ_SIZE := Vector2(800, 608)
func _on_resized() -> void:
	# center it
	inner_container.position = (size - OBJ_SIZE) / 2
	inner_container.size = OBJ_SIZE

func _ready() -> void:
	level.door_clicked.connect(_on_door_clicked)
	level.key_clicked.connect(_on_key_clicked)
	resized.connect(_on_resized)
	level_viewport.size = Vector2i(800, 608)
	level_viewport.get_parent().show()
	ghost_canvas_group.self_modulate.a = 0.5
	
	await get_tree().process_frame
	editor_data.selected_highlight = selected_highlight
	editor_data.danger_highlight = danger_highlight
	editor_data.hover_highlight = level.hover_highlight
	
	editor_data.side_tabs.tab_changed.connect(_retry_ghosts.unbind(1))
	editor_data.level.changed_doors.connect(_retry_ghosts)
	editor_data.level.changed_keys.connect(_retry_ghosts)
	# deferred: fixes the door staying at the old mouse position (since the level pos moves when the editor kicks in)
	editor_data.changed_is_playing.connect(_retry_ghosts, CONNECT_DEFERRED)
	_place_ghost_door()
	_place_ghost_key()
	selected_highlight.adapted_to.connect(_on_selected_highlight_adapted_to)

func _on_door_clicked(event: InputEventMouseButton, door: Door) -> void:
	if editor_data.disable_editing: return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			level.remove_door(door)
			accept_event()
			selected_highlight.stop_adapting()
			hover_highlight.stop_adapting()
	elif event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			editor_data.door_editor.door_data = door.door_data
			editor_data.side_tabs.current_tab = editor_data.side_tabs.get_tab_idx_from_control(editor_data.door_editor)
			selected_highlight.adapt_to(door)

func _on_key_clicked(event: InputEventMouseButton, key: Key) -> void:
	if editor_data.disable_editing: return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			level.remove_key(key)
			accept_event()
			selected_highlight.stop_adapting()
			hover_highlight.stop_adapting()
	elif event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			editor_data.key_editor.key_data = key.key_data
			editor_data.side_tabs.current_tab = editor_data.side_tabs.get_tab_idx_from_control(editor_data.key_editor)
			selected_highlight.adapt_to(key)

func _gui_input(event: InputEvent) -> void:
	if editor_data.disable_editing: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				grab_focus()
				if editor_data.tilemap_edit:
					place_tile_on_mouse()
					accept_event()
				elif editor_data.doors:
					if place_door_on_mouse():
						accept_event()
				elif editor_data.keys:
					if place_key_on_mouse():
						accept_event()
				elif editor_data.level_properties:
					if editor_data.player_spawn:
						place_player_spawn_on_mouse()
						accept_event()
					elif editor_data.goal_position:
						place_goal_on_mouse()
						accept_event()
				consider_unselect()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
#				if editor_data.tilemap_edit:
				if remove_tile_on_mouse():
					accept_event()
				consider_unselect()
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if is_instance_valid(editor_data.selected) && editor_data.is_dragging:
				relocate_selected()
			if editor_data.tilemap_edit:
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

# TODO: Improve this whole thing to make sense :)
func _physics_process(_delta: float) -> void:
	_place_ghost_door()
	_place_ghost_key()
	if editor_data.is_dragging:
		ghost_door.hide()
		ghost_key.hide()
		selected_highlight.adapt_to(editor_data.selected)
		hover_highlight.hide()

func consider_unselect() -> void:
	if is_instance_valid(selected_highlight.current_obj):
		if not selected_highlight.current_obj.get_rect().intersects(Rect2(get_mouse_coord(1), Vector2.ONE)):
			selected_highlight.stop_adapting()

func place_tile_on_mouse() -> void:
	if editor_data.disable_editing: return
	if is_mouse_out_of_bounds(): return
	var coord = get_mouse_tile_coord(32)
	level.place_tile(coord)

func remove_tile_on_mouse() -> bool:
	if editor_data.disable_editing: return false
	if is_mouse_out_of_bounds(): return false
	var coord = get_mouse_tile_coord(32)
	return level.remove_tile(coord)

func place_door_on_mouse() -> bool:
	if editor_data.disable_editing: return false
	if is_mouse_out_of_bounds(): return false
	var coord = get_mouse_coord(32)
	var door_data := door_editor.door.door_data.duplicated()
	door_data.position = coord
	var door := level.add_door(door_data)
	if not is_instance_valid(door): return false
	selected_highlight.adapt_to(door)
	hover_highlight.adapt_to(door)
	danger_highlight.stop_adapting()
	return true

func place_key_on_mouse() -> bool:
	if editor_data.disable_editing: return false
	if is_mouse_out_of_bounds(): return false
	var coord = get_mouse_coord(16)
	var key_data := key_editor.key.key_data.duplicated()
	key_data.position = coord
	var key := level.add_key(key_data)
	if not is_instance_valid(key): return false
	selected_highlight.adapt_to(key)
	hover_highlight.adapt_to(key)
	danger_highlight.stop_adapting()
	return true

func place_player_spawn_on_mouse() -> void:
	if editor_data.disable_editing: return
	if is_mouse_out_of_bounds(): return
	var coord = get_mouse_coord(16)
	level.place_player_spawn(coord)

func place_goal_on_mouse() -> void:
	if editor_data.disable_editing: return
	if is_mouse_out_of_bounds(): return
	var coord = get_mouse_coord(16)
	level.place_goal(coord)

func relocate_selected() -> void:
	if editor_data.disable_editing: return
	if is_mouse_out_of_bounds(): return
	if not editor_data.is_dragging: return
	if not is_instance_valid(editor_data.selected): return
	var selected := editor_data.selected
	var grid_size := 32
	if selected is Door:
		grid_size = 32
	elif selected is Key:
		grid_size = 16
	var old_coord := round_coord(editor_data.drag_position, grid_size)
	var new_coord := get_mouse_coord(grid_size)
	if selected is Door:
		level.move_door(selected, new_coord)
	elif selected is Key:
		level.move_key(selected, new_coord)
	else:
		assert(false)
	

func get_mouse_coord(grid_size: int) -> Vector2i:
	return round_coord(Vector2i(get_global_mouse_position() - get_level_pos()), grid_size)

func get_mouse_tile_coord(grid_size: int) -> Vector2i:
	return Vector2i((get_global_mouse_position() - get_level_pos()) / Vector2(grid_size, grid_size))

func round_coord(coord: Vector2i, grid_size: int) -> Vector2i:
	return coord / Vector2i(grid_size, grid_size) * Vector2i(grid_size, grid_size)

func is_mouse_out_of_bounds() -> bool:
	var local_pos := get_global_mouse_position() - get_level_pos()
	if local_pos.x < 0 or local_pos.y < 0 or local_pos.x >= level.level_data.size.x or local_pos.y >= level.level_data.size.y:
		return true
	return false

func get_level_pos() -> Vector2:
	return level_viewport.get_parent().global_position + level.global_position

func _retry_ghosts() -> void:
	ghost_key.hide()
	ghost_door.hide()
	_place_ghost_door()
	_place_ghost_key()

func _place_ghost_door() -> void:
	if not editor_data.doors or editor_data.is_playing:
		ghost_door.hide()
		return
	ghost_door.door_data = door_editor.door_data
	var maybe_pos := get_mouse_coord(32)
	ghost_door.position = maybe_pos
	if not Rect2i(Vector2i.ZERO, level.level_data.size).has_point(maybe_pos):
		ghost_door.hide()
		danger_highlight.hide()
		return
	if not level.is_space_occupied(Rect2i(maybe_pos, ghost_door.get_rect().size)):
		ghost_door.show()
	else:
		ghost_door.hide()
		
	if (
	not is_instance_valid(level.hovering_over)
	and not ghost_door.visible
	# TODO: This is just a double-check, but looks weird since tiles can't be hovered on yet
#	and not level.is_space_occupied(Rect2i(get_mouse_coord(1), Vector2.ONE))
	):
		danger_highlight.show()
		danger_highlight.adapt_to(ghost_door)
	else:
		danger_highlight.hide()

func _place_ghost_key() -> void:
	if not editor_data.keys or editor_data.is_playing:
		ghost_key.hide()
		return
	ghost_key.key_data = key_editor.key_data
	var maybe_pos := get_mouse_coord(16)
	if not Rect2i(Vector2i.ZERO, level.level_data.size).has_point(maybe_pos):
		ghost_key.hide()
		return
	if not level.is_space_occupied(Rect2i(maybe_pos, Vector2i(32, 32))):
		ghost_key.position = maybe_pos
		ghost_key.show()

func _on_selected_highlight_adapted_to(_obj: Node) -> void:
	if (Input.get_mouse_button_mask() & MOUSE_BUTTON_MASK_LEFT):
		editor_data.drag_position = get_mouse_coord(1)
		editor_data.is_dragging = true
