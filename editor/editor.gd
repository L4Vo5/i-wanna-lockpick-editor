extends Control

@onready var tile_map: TileMap = %TileMap

enum modes {
	tilemap_edit
}
var mode := modes.tilemap_edit

func _enter_tree() -> void:
	Global.in_level_editor = true

func _exit_tree() -> void:
	Global.in_level_editor = false

func _ready() -> void:
	var l = 0
#	tile_map.set_cell(l, Vector2i(4,1), 1, Vector2i(0, 0))
	Global.set_mode(Global.Modes.EDITOR)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("place_tile"):
		place_tile_on_mouse()
	if event.is_action_pressed("remove_tile"):
		remove_tile_from_mouse()

func place_tile_on_mouse() -> void:
	var layer := 0
	var id := 1
	var coord = Vector2i(get_local_mouse_position() / Vector2(32, 32))
	tile_map.set_cell(layer, coord, id, Vector2i(0, 0))

func remove_tile_from_mouse() -> void:
	var layer := 0
	var coord = Vector2i(get_local_mouse_position() / Vector2(32, 32))
	tile_map.erase_cell(layer, coord)
