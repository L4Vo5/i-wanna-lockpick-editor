extends Control

@onready var tile_map: TileMap = %TileMap

func _enter_tree() -> void:
	Global.in_level_editor = true

func _exit_tree() -> void:
	Global.in_level_editor = false

func _ready() -> void:
	var l = 0
	tile_map.set_cell(l, Vector2i(4,1), 1, Vector2i(0, 0))
