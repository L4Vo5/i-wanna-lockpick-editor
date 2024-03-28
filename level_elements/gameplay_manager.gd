extends Node2D
class_name GameplayManager
## Manages a Level, and handles the progression and transition between levels in a LevelPack

var pack_data: LevelPackData:
	set = load_level_pack, get = get_level_pack
var _pack_data: LevelPackData
var pack_state: LevelPackStateData

@onready var level: Level = %Level

func _ready() -> void:
	level.gameplay_manager = self

func load_level_pack(pack: LevelPackData) -> void:
	load_level_pack_from_state(LevelPackStateData.make_from_pack_data(pack))

func get_level_pack() -> LevelPackData:
	return _pack_data

func load_level_pack_from_state(state: LevelPackStateData) -> void:
	_pack_data = state.pack_data
	pack_state = state
	var level_data: LevelData = _pack_data.levels[state.current_level]
	level.level_data = level_data

## Transitions to a different level in the pack
func transition_to_level(id: int) -> void:
	if id == pack_state.current_level:
		reset()
	else:
		pack_state.current_level = id

func reset() -> void:
	level.reset()
