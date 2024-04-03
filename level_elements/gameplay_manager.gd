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
	# Try to load save data for the level, otherwise make new save data
	# TODO: Obviously don't do it this way, specially if I revamp the .lvl select
	var pack_id := pack.pack_id
	var state: LevelPackStateData = null
	for file_name in DirAccess.get_files_at("user://level_saves"):
		var file_path := "user://level_saves".path_join(file_name)
		var possible_state = load(file_path)
		if possible_state is LevelPackStateData:
			if possible_state.pack_id == pack_id:
				state = possible_state
				state.pack_data = pack
	if not state:
		state = LevelPackStateData.make_from_pack_data(pack)
		var i := randi()
		while FileAccess.file_exists("user://level_saves/" + str(i) + ".tres"):
			i = randi()
		state.resource_path = "user://level_saves/" + str(i) + ".tres"
		state.save()
		print("Couldn't find save data, making a new one at %s" % state.resource_path)
	else:
		print("Successfully loaded save data from %s!" % state.resource_path)
	load_level_pack_from_state(state)

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
		var level_data: LevelData = _pack_data.levels[pack_state.current_level]
		level.level_data = level_data
		reset()

func reset() -> void:
	level.reset()
