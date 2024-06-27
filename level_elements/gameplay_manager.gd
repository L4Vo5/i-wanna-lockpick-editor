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

## Sets the current level to the given level id within the pack and loads it.
func set_current_level(id: int) -> void:
	assert(PerfManager.start("GameplayManager::set_current_level (%d)" % id))
	if id == pack_state.current_level:
		reset()
	else:
		pack_state.current_level = id
		pack_state.save()
		var level_data: LevelData = _pack_data.levels[pack_state.current_level]
		level.level_data = level_data
		reset()
	assert(PerfManager.end("GameplayManager::set_current_level (%d)" % id))

func has_won_current_level() -> bool:
	return pack_state.completed_levels[pack_state.current_level] == 1

func reset() -> void:
	level.reset()

func win() -> void:
	if pack_state.completed_levels[pack_state.current_level] != 1:
		pack_state.completed_levels[pack_state.current_level] = 1
		pack_state.save()
	win_animation("Congratulations!")

func can_exit() -> bool:
	var exit = pack_state.exit_level
	if exit < 0 or exit >= _pack_data.levels.size():
		return false
	return true

func exit_level() -> void:
	if not can_exit():
		return
	transition.world_enter_animation()
	transition.finished_animation.connect(exit_immediately, CONNECT_ONE_SHOT)

## Exits WITHOUT checking
func exit_immediately() -> void:
	set_current_level(pack_state.exit_level)
	level.player.position = pack_state.exit_position

func exit_or_reset() -> void:
	if can_exit():
		exit_immediately()
	else:
		reset()

func enter_level(id: int, exit_position: Vector2i) -> void:
	# set exit parameters
	pack_state.exit_level = pack_state.current_level
	pack_state.exit_position = exit_position
	
	var _new_level_data := _pack_data.levels[id]
	var target_level_name := _new_level_data.name
	var target_level_title := _new_level_data.title
	transition.level_enter_animation(target_level_name, target_level_title)
	await transition.finished_animation
	set_current_level(id)

func win_animation(text: String) -> void:
	transition.win_animation(text)
	transition.finished_animation.connect(exit_or_reset, CONNECT_ONE_SHOT)
