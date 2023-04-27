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

@export var editor: LockpickEditor
var editor_data: EditorData

#var level_offset :=  Vector2(0, 0)

const OBJ_SIZE := Vector2(800, 608)
func _on_resized() -> void:
	# center it
	inner_container.position = (size - OBJ_SIZE) / 2
	inner_container.size = OBJ_SIZE

var selected = null
func _ready() -> void:
	level.door_clicked.connect(_on_door_clicked)
	level.key_clicked.connect(_on_key_clicked)
	resized.connect(_on_resized)
	level_viewport.size = Vector2i(800, 608)

func _on_door_clicked(event: InputEventMouseButton, door: Door) -> void:
	if editor_data.disable_editing: return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			level.remove_door(door)
			accept_event()
	elif event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			editor_data.door_editor.door_data = door.door_data
			editor_data.side_tabs.current_tab = editor_data.side_tabs.get_tab_idx_from_control(editor_data.door_editor)

func _on_key_clicked(event: InputEventMouseButton, key: Key) -> void:
	if editor_data.disable_editing: return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			level.remove_key(key)
			accept_event()
	elif event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			editor_data.key_editor.key_data = key.key_data
			editor_data.side_tabs.current_tab = editor_data.side_tabs.get_tab_idx_from_control(editor_data.key_editor)

func _gui_input(event: InputEvent) -> void:
	if editor_data.disable_editing: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if editor_data.tilemap_edit:
					place_tile_on_mouse()
					accept_event()
				elif editor_data.doors:
					place_door_on_mouse()
					accept_event()
				elif editor_data.keys:
					place_key_on_mouse()
					accept_event()
				elif editor_data.level_properties:
					if editor_data.player_spawn:
						place_player_spawn_on_mouse()
						accept_event()
					elif editor_data.goal_position:
						place_goal_on_mouse()
						accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
#				if editor_data.tilemap_edit:
					if remove_tile_on_mouse():
						accept_event()
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
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

func place_door_on_mouse() -> void:
	if editor_data.disable_editing: return
	if is_mouse_out_of_bounds(): return
	var coord = get_mouse_coord(32)
	var door_data := door_editor.door.door_data.duplicated()
	door_data.position = coord
	level.add_door(door_data)

func place_key_on_mouse() -> void:
	if editor_data.disable_editing: return
	if is_mouse_out_of_bounds(): return
	var coord = get_mouse_coord(16)
	var key_data := key_editor.key.key_data.duplicated()
	key_data.position = coord
	level.add_key(key_data)

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

func get_mouse_coord(grid_size: int) -> Vector2i:
	return Vector2i(get_global_mouse_position() - get_level_pos()) / Vector2i(grid_size, grid_size) * Vector2i(grid_size, grid_size)

func get_mouse_tile_coord(grid_size) -> Vector2i:
	return Vector2i((get_global_mouse_position() - get_level_pos()) / Vector2(grid_size, grid_size))

func is_mouse_out_of_bounds() -> bool:
	var local_pos := get_global_mouse_position() - get_level_pos()
	if local_pos.x < 0 or local_pos.y < 0 or local_pos.x >= level.level_data.size.x or local_pos.y >= level.level_data.size.y:
		return true
	return false

func get_level_pos() -> Vector2:
	return level_viewport.get_parent().global_position + level.global_position
