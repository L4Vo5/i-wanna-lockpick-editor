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

var enter_stack: Array[level_enter_entry] = []

class level_enter_entry:
	extends RefCounted
	
	var level_id: int
	var entry_pos: Vector2
	
	func _init(id: int, pos: Vector2):
		level_id = id
		entry_pos = pos

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
	win_animation("Congratulations!")

func win_animation(text: String) -> void:
	transition.win_animation(text)
	await transition.finished_animation
	if not exit_level_immediately():
		level.reset()

func exit_level() -> void:
	if enter_stack.is_empty():
		return
	var element: level_enter_entry = enter_stack.pop_back()
	var level_id = element.level_id
	var entry_pos = element.entry_pos
	transition.world_enter_animation()
	await transition.finished_animation
	transition_to_level(level_id)
	level.player.position = entry_pos

func exit_level_immediately() -> bool:
	if enter_stack.is_empty():
		return false
	var element: level_enter_entry = enter_stack.pop_back()
	var level_id = element.level_id
	var entry_pos = element.entry_pos
	transition_to_level(level_id)
	level.player.position = entry_pos
	return true

func enter_level(id: int) -> void:
	var _new_level_data := _pack_data.levels[id]
	if _new_level_data.world_completion_count != -1:
		enter_stack.clear()
		transition.world_enter_animation()
	else:
		var target_level_name := _new_level_data.name
		var target_level_title := _new_level_data.title
		transition.level_enter_animation(target_level_name, target_level_title)
		
		enter_stack.push_back(level_enter_entry.new(pack_state.current_level, level.player.position))
	await transition.finished_animation
	transition_to_level(id)
