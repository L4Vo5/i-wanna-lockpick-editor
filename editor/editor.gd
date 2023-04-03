extends Control

const DOOR := preload("res://level_elements/doors_locks/door.tscn")

@onready var tile_map: TileMap = %TileMap
@onready var level: Level = %Level
@onready var door_editor: DoorEditor = %DoorEditor

# tools
@onready var action: OptionButton = %Action

enum modes {
	tilemap_edit
}
var mode := modes.tilemap_edit

func _enter_tree() -> void:
	Global.in_level_editor = true

func _exit_tree() -> void:
	Global.in_level_editor = false

func _ready() -> void:
#	tile_map.set_cell(l, Vector2i(4,1), 1, Vector2i(0, 0))
	Global.set_mode(Global.Modes.EDITOR)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("place_tile"):
		if get_action_text() == "place/delete tiles":
			place_tile_on_mouse()
		elif get_action_text() == "place/delete doors":
			place_door_on_mouse()
	if event.is_action_pressed("remove_tile"):
		if get_action_text() == "place/delete tiles":
			remove_tile_on_mouse()
		elif get_action_text() == "place/delete doors":
			remove_door_on_mouse()
	if event is InputEventMouseMotion:
		if Input.is_action_pressed("place_tile"):
			if get_action_text() == "place/delete tiles":
				place_tile_on_mouse()
		if Input.is_action_pressed("remove_tile"):
			if get_action_text() == "place/delete tiles":
				remove_tile_on_mouse()

func get_action_text() -> String:
	return action.text.to_lower()

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
