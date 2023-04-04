extends Control
class_name LevelContainer
## Contains the level, centered, and at the correct aspect ratio
## Also is just the level editor for general input reasons (this should've been LevelContainerInner maybe but it's not that strong of a reason to clutter the responsibilities further)

@export var DOOR: PackedScene

@export var inner_container: Control
@export var level: Level

@export var tile_map: TileMap
@export var door_editor: DoorEditor

#var level_offset :=  Vector2(0, 0)

const OBJ_SIZE := Vector2(800, 608)
func _process(delta: float) -> void:
	# center it
	inner_container.position = (size - OBJ_SIZE) / 2
	inner_container.size = OBJ_SIZE

var selected = null

var mode := Enums.editor_modes.tilemap_edit

#func _gui_input(event: InputEvent) -> void:
#	if event.is_action_pressed("place_tile"):
#		if mode == modes.tilemap_edit:
#			place_tile_on_mouse()
#			accept_event()
#		elif mode == modes.doors_keys:
#			place_door_on_mouse()
#			accept_event()
#	if event.is_action_pressed("remove_tile"):
#		if mode == modes.tilemap_edit:
#			remove_tile_on_mouse()
#			accept_event()
#		elif mode == modes.doors_keys:
#			remove_door_on_mouse()
#			accept_event()
#	if event is InputEventMouseMotion:
#		if Input.is_action_pressed("place_tile"):
#			if mode == modes.tilemap_edit:
#				place_tile_on_mouse()
#				accept_event()
#		if Input.is_action_pressed("remove_tile"):
#			if mode == modes.tilemap_edit:
#				remove_tile_on_mouse()
#				accept_event()


func place_tile_on_mouse() -> void:
	var layer := 0
	var id := 1
	var coord = get_mouse_tile_coord()
	tile_map.set_cell(layer, coord, id, Vector2i(1, 1))

func remove_tile_on_mouse() -> void:
	var layer := 0
	var coord = get_mouse_tile_coord()
	tile_map.erase_cell(layer, coord)

func place_door_on_mouse() -> void:
	var coord = get_mouse_door_coord()
	var new_door = DOOR.instantiate()
	new_door.door_data = door_editor.door.door_data.duplicated()
	new_door.door_data.position = coord
	level.add_child(new_door)

func remove_door_on_mouse() -> void:
	var coord = get_mouse_door_coord()
	for door in level.get_doors():
		if door.door_data.has_point(coord):
			level.remove_door(door)
			break

func get_mouse_door_coord() -> Vector2i:
	return Vector2i(get_local_mouse_position() - level.global_position) / Vector2i(32, 32) * Vector2i(32, 32)

func get_mouse_tile_coord() -> Vector2i:
	return Vector2i((get_local_mouse_position() - level.global_position) / Vector2(32, 32))
