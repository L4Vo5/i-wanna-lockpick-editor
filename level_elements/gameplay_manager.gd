extends Node2D
class_name GameplayManager
## Manages a Level, and handles the progression and transition between levels in a LevelPack

var level_pack: LevelPackData
var pack_state: LevelPackStateData

@onready var level: Level = %Level

func loadlevel_pack_from_state(state: LevelPackStateData) -> void:
	level_pack = state.pack_data
	pack_state = state
	var level_data: LevelData = level_pack.levels[state.current_level]
	level.level_data = level_data

## Transitions to a different level in the pack
func transition_to_level(id: int) -> void:
	if id == pack_state.current_level:
		reset()
	else:
		pack_state.current_level = id

func reset() -> void:
	level.reset()
