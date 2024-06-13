extends Node2D
class_name GameplayManager
## Manages a Level, and handles the progression and transition between levels in a LevelPack

var pack_data: LevelPackData:
	set = load_level_pack, get = get_level_pack
var _pack_data: LevelPackData
var pack_state: LevelPackStateData:
	get:
		return _pack_data.state_data

@onready var level: Level = %Level

@onready var transition: Transition = %Transition

func _ready() -> void:
	level.gameplay_manager = self

func load_level_pack(pack: LevelPackData) -> void:
	assert(PerfManager.start("GameplayManager::load_level_pack"))
	_pack_data = pack
	var state := LevelPackStateData.find_state_file_for_pack_or_create_new(_pack_data)
	_pack_data.state_data = state
	var level_data: LevelData = _pack_data.levels[state.current_level]
	level.level_data = level_data
	reset()
	assert(PerfManager.end("GameplayManager::load_level_pack"))

func get_level_pack() -> LevelPackData:
	return _pack_data

## Transitions to a different level in the pack
# TODO: consider renaming? sicnce "transition" implies animation. this just switches the level
func transition_to_level(id: int) -> void:
	assert(PerfManager.start("GameplayManager::transition_to_level (%d)" % id))
	if id == pack_state.current_level:
		reset()
	else:
		pack_state.current_level = id
		pack_state.save()
		var level_data: LevelData = _pack_data.levels[pack_state.current_level]
		level.level_data = level_data
		reset()
	assert(PerfManager.end("GameplayManager::transition_to_level (%d)" % id))

func has_won_current_level() -> bool:
	return pack_state.completed_levels[pack_state.current_level] == 1

func reset() -> void:
	level.reset()

func win() -> void:
	if pack_state.completed_levels[pack_state.current_level] != 1:
		pack_state.completed_levels[pack_state.current_level] = 1
		pack_state.save()
	transition.finished_animation.connect(level.reset)
	transition.win_animation("Congratulations!")

func enter_level(id: int) -> void:
	var _new_level_data := _pack_data.levels[id]
	var target_level_name := _new_level_data.name
	var target_level_title := _new_level_data.title
	transition.level_enter_animation(target_level_name, target_level_title)
	await transition.finished_animation
	transition_to_level(id)
