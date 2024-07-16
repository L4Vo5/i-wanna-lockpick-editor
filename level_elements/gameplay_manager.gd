extends Node2D
class_name GameplayManager
## Manages a Level, and handles the progression and transition between levels in a LevelPack

var pack_data: LevelPackData:
	set = load_level_pack, get = get_level_pack
var _pack_data: LevelPackData
var pack_state: LevelPackStateData:
	get:
		return _pack_data.state_data
var test_state: LevelPackStateData
var active_state: LevelPackStateData:
	get:
		return test_state if mode == PlayMode.TESTING else pack_state

var current_level: int
## For EDITOR no state is modified, for TESTING test_state is modified, for PLAYING pack_state is modified
var mode := PlayMode.EDITOR

enum PlayMode {
	EDITOR,
	TESTING,
	PLAYING
}

@onready var level: Level = %Level

@onready var transition: Transition = %Transition

func _ready() -> void:
	level.gameplay_manager = self

func set_play_mode(play_mode: PlayMode) -> void:
	print("Transitioning to ", PlayMode.find_key(play_mode))
	mode = play_mode
	match play_mode:
		PlayMode.EDITOR:
			# delete test state if it exists
			test_state = null
			reset()
		PlayMode.TESTING:
			# new test state
			test_state = LevelPackStateData.make_from_pack_data(_pack_data)
			test_state.current_level = _pack_data.levels[current_level].unique_id
			reset()
		PlayMode.PLAYING:
			# synchronize with pack state
			if Global.danger_override and Input.is_key_pressed(KEY_CTRL):
				# allow entering to anywhere for editor / pack state testing idk
				pack_state.current_level = _pack_data.levels[current_level].unique_id
				reset()
			else:
				set_current_level_unique_id(pack_state.current_level)

func load_level_pack(pack: LevelPackData) -> void:
	assert(PerfManager.start("GameplayManager::load_level_pack"))
	_pack_data = pack
	var state := LevelPackStateData.find_state_file_for_pack_or_create_new(_pack_data)
	_pack_data.state_data = state
	set_current_level_unique_id(state.current_level)
	assert(PerfManager.end("GameplayManager::load_level_pack"))

func get_level_pack() -> LevelPackData:
	return _pack_data

## Sets the current level to the given level id within the pack and loads it.
func set_current_level(id: int) -> void:
	assert(PerfManager.start("GameplayManager::set_current_level (%d)" % id))
	current_level = id
	var level_data: LevelData = _pack_data.levels[current_level]
	if mode == PlayMode.TESTING:
		test_state.current_level = level_data.unique_id
	elif mode == PlayMode.PLAYING:
		pack_state.current_level = level_data.unique_id
		pack_state.save()
	assert(_pack_data.levels_by_id[level_data.unique_id] == level_data)
	level.level_data = level_data
	reset()
	assert(PerfManager.end("GameplayManager::set_current_level (%d)" % id))

func set_current_level_unique_id(unique_id: int) -> void:
	# I don't think there's something much better ... well find doesn't take too long though
	var lvl: LevelData = _pack_data.levels_by_id.get(unique_id)
	if lvl == null:
		printerr("Invalid unique id ", String.num_uint64(unique_id, 16))
		return set_current_level(0)
	set_current_level(_pack_data.levels.find(lvl))

func has_won_current_level() -> bool:
	return active_state.completed_levels.has(_pack_data.levels[current_level].unique_id)

func reset() -> void:
	level.reset()

func win() -> void:
	if not has_won_current_level():
		active_state.completed_levels[_pack_data.levels[current_level].unique_id] = 1
		if mode == PlayMode.PLAYING:
			pack_state.save()
	win_animation("Congratulations!")

func can_exit() -> bool:
	var state := active_state
	while not state.exit_levels.is_empty():
		var exit: int = state.exit_levels[-1]
		if _pack_data.levels_by_id.has(exit):
			if _pack_data.levels_by_id[exit].exitable:
				return true
			state.exit_levels.clear()
			state.exit_positions.clear()
			return false
		state.exit_levels.remove_at(state.exit_levels.size() - 1)
		state.exit_positions.pop_back()
	return false

func exit_level() -> void:
	if not can_exit():
		return
	transition.world_enter_animation()
	transition.finished_animation.connect(exit_immediately, CONNECT_ONE_SHOT)

## Exits WITHOUT checking
func exit_immediately() -> void:
	assert(mode != PlayMode.EDITOR)
	var exit_pos: Vector2i = active_state.exit_positions.pop_back()
	var exit_lvl: int = active_state.exit_levels[-1]
	active_state.exit_levels.remove_at(active_state.exit_levels.size() - 1)
	set_current_level_unique_id(exit_lvl)
	level.player.position = exit_pos

func exit_or_reset() -> void:
	if can_exit():
		exit_immediately()
	else:
		reset()

func enter_level(id: int, exit_position: Vector2i) -> void:
	assert(mode != PlayMode.EDITOR)
	# push onto exit stack
	var state := active_state
	if _pack_data.levels[id].exitable:
		state.exit_levels.push_back(state.current_level)
		state.exit_positions.push_back(exit_position)
	else:
		state.exit_levels.clear()
		state.exit_positions.clear()
	
	var _new_level_data := _pack_data.levels[id]
	var target_level_name := _new_level_data.name
	var target_level_title := _new_level_data.title
	transition.level_enter_animation(target_level_name, target_level_title)
	await transition.finished_animation
	set_current_level(id)

func win_animation(text: String) -> void:
	transition.win_animation(text)
	transition.finished_animation.connect(exit_or_reset, CONNECT_ONE_SHOT)
