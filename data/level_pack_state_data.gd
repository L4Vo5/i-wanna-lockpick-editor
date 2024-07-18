extends Resource
class_name LevelPackStateData
## The state of a level pack. Also doubles as save data.

static var SHOULD_PRINT := false

## Id of the pack this state data corresponds to.
# File path and pack id should coincide, so this seems useless.
# But, keeping track of it is helpful to double check if the file was renamed by a user or something.
@export var pack_id: int

## The actual pack data
var pack_data: LevelPackData

## An array with the completion status of each level (0: incomplete, 1: completed).
## A level is completed when you reach the goal.
@export var completed_levels: PackedByteArray

## The salvaged doors. Their origin doesn't matter.
@export var salvaged_doors: Array[DoorData] = []

## The current level that's being played in the pack.
@export var current_level: int

## The level that you reach when exiting (backspace), for each other level.
@export var exit_levels: PackedInt32Array = []

## The player position within exit_level after exiting
@export var exit_positions: Array[Vector2i] = []

static func make_from_pack_data(pack: LevelPackData) -> LevelPackStateData:
	var state := LevelPackStateData.new()
	state.completed_levels = []
	state.completed_levels.resize(pack.levels.size())
	state.exit_levels = []
	state.exit_positions = []
	state.pack_id = pack.pack_id
	state.pack_data = pack
	state.connect_pack_data()
	return state

func connect_pack_data() -> void:
	if not pack_data: return
	pack_data.added_level.connect(_on_added_level)
	pack_data.deleted_level.connect(_on_deleted_level)
	pack_data.swapped_levels.connect(_on_swapped_levels)
	pack_data.moved_level.connect(_on_moved_levels)

func salvage_door(sid: int, door: DoorData) -> void:
	if sid < 0 or sid > 999:
		return
	if salvaged_doors.size() < sid + 1:
		salvaged_doors.resize(sid + 1)
	salvaged_doors[sid] = door
	save()

func get_completed_levels_count() -> int:
	return completed_levels.count(1)

func get_salvaged_doors_count() -> int:
	return salvaged_doors.reduce(func(accum, door):
		return accum + (1 if door else 0)
	, 0)

func _on_added_level(id: int) -> void:
	assert(pack_data.levels.size() == completed_levels.size() + 1)
	completed_levels.insert(id, 0)
	for i in exit_levels.size():
		if exit_levels[i] >= id:
			exit_levels[i] += 1
	save()

func _on_deleted_level(level_id: int) -> void:
	assert(pack_data.levels.size() == completed_levels.size() - 1)
	completed_levels.remove_at(level_id)
	for i in exit_levels.size():
		if exit_levels[i] == level_id:
			exit_levels.remove_at(i)
			exit_positions.remove_at(i)
			i -= 1
		elif exit_levels[i] >= level_id:
			exit_levels[i] -= 1
	assert(pack_data.levels.size() == completed_levels.size())
	save()

func _on_swapped_levels(level_1_id: int, level_2_id: int) -> void:
	array_swap(completed_levels, level_1_id, level_2_id)
	for i in exit_levels.size():
		if exit_levels[i] == level_1_id:
			exit_levels[i] = level_2_id
		elif exit_levels[i] == level_2_id:
			exit_levels[i] = level_1_id
	save()

func _on_moved_levels(from_id: int, to_id: int) -> void:
	array_move(completed_levels, from_id, to_id)
	for i in exit_levels.size():
		if exit_levels[i] == from_id:
			exit_levels[i] = to_id
		elif to_id > from_id:
			if exit_levels[i] > from_id and exit_levels[i] <= to_id:
				exit_levels[i] -= 1
		else:
			if exit_levels[i] >= to_id and exit_levels[i] < from_id:
				exit_levels[i] += 1
	save()

func array_swap(array: Array, id_1: int, id_2: int) -> void:
	var v = array[id_1]
	array[id_1] = array[id_2]
	array[id_2] = v

func array_move(array: Array, from: int, to: int) -> void:
	var v = array[from]
	array.remove_at(from)
	array.insert(to, v)

func save() -> void:
	assert(pack_id == pack_data.pack_id)
	if pack_data.file_path == "":
		# Don't save.
		return
	# File path is recalculated before saving, in case the user changed the pack from .lvlst to .tres or something
	var file_path := get_path_from_pack(pack_data)
	pr("Saving state data to %s" % file_path)
	if file_path.get_extension() == "lvlst":
		SaveLoad.save_pack_state_to_path(self, file_path)
	elif file_path.get_extension() in ["tres", "res"]:
		ResourceSaver.save(self, file_path)

func check_and_fix() -> void:
	# TODO: maybe improve (what if there's extra salvages? etc)
	var pack_level_count := pack_data.levels.size()
	# hack but this is the easiest way to make sure they all have the appropiate size i guess
	var current_level_count := completed_levels.size()
	if current_level_count != pack_level_count:
		printerr("state is keeping track of %d levels, but level pack has %d, resizing." % [current_level_count, pack_level_count])
		completed_levels.resize(pack_level_count)
	if current_level < 0 or current_level >= pack_data.levels.size():
		printerr("State's current level is out of range: current level = ",
			current_level, " level count ", pack_data.levels.size())
		current_level = 0

static func load_pack_state(path: String, pack: LevelPackData) -> LevelPackStateData:
	var state: LevelPackStateData
	if path.get_extension() == "lvlst":
		state = SaveLoad.load_pack_state_from_path(path)
	elif path.get_extension() in ["tres", "res"]:
		if FileAccess.file_exists(path):
			state = load(path)
	if not state:
		return null
	assert(state.pack_id == pack.pack_id)
	state.pack_data = pack
	state.connect_pack_data()
	state.check_and_fix()
	return state

static func find_state_file_for_pack_or_create_new(pack: LevelPackData) -> LevelPackStateData:
	var state: LevelPackStateData = null
	var path := get_path_from_pack(pack)
	state = load_pack_state(path, pack)
	if not state:
		state = make_from_pack_data(pack)
		pr("Couldn't find save data, making a new one")
	else:
		pr("Successfully loaded save data from %s!" % path)
	assert(state.pack_id == pack.pack_id)
	return state

static func get_path_from_pack(pack: LevelPackData) -> String:
	var pack_path := pack.file_path if not pack.file_path.is_empty() else pack.resource_path
	if pack_path.is_empty():
		return ""
	var extension := "." + pack_path.get_extension()
	if extension == ".lvl":
		extension = ".lvlst"
	var file_name := str(pack.pack_id) + extension
	return SaveLoad.SAVES_PATH.path_join(file_name)

func delete_file() -> void:
	var file_path := get_path_from_pack(pack_data)
	DirAccess.remove_absolute(file_path)

static func pr(s: String) -> void:
	if SHOULD_PRINT:
		print(s)
