@tool
extends MarginContainer
class_name TileEditor

static var tile_set: TileSet = load("res://rendering/tiles/tileset.tres")

@onready var tile_choice: ObjectGridChooser = %TileChoice

var node_to_id: Dictionary = {}
var id_to_node: Dictionary = {}

var tile_type: int:
	set(val):
		tile_choice.selected_object = id_to_node[val]
	get:
		if not tile_choice.selected_object:
			return 0
		return node_to_id[tile_choice.selected_object]

func _ready():
	tile_choice.clear()
	for i in tile_set.get_source_count():
		var id := tile_set.get_source_id(i)
		var pos: Vector2i = AutoTiling.tiling_lookups[id][0]
		var tile_map := TileMap.new()
		tile_map.tile_set = tile_set
		tile_map.set_cell(0, Vector2i.ZERO, id, pos)
		var tile_control := Control.new()
		tile_control.add_child(tile_map)
		tile_choice.add_child(tile_control, true)
		tile_control.custom_minimum_size = Vector2i(32, 32)
		tile_control.size = Vector2i(32, 32)
		tile_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node_to_id[tile_control] = id
		id_to_node[id] = tile_control
