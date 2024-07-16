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

## A dictionary of all completed levels by unique id.
## The values currently have no meaning.
@export var completed_levels: Dictionary

## The salvaged doors. Their origin doesn't matter.
@export var salvaged_doors: Array[DoorData] = []

## The current level by unique id that's being played in the pack.
@export var current_level: int

## The levels by unique id that you reach when exiting (backspace), as a stack.
@export var exit_levels: PackedInt64Array = []

## The player positions within exit_levels after exiting
@export var exit_positions: Array[Vector2i] = []

static func make_from_pack_data(pack: LevelPackData) -> LevelPackStateData:
	var state := LevelPackStateData.new()
	state.completed_levels = {}
	state.exit_levels = []
	state.exit_positions = []
	state.pack_id = pack.pack_id
	state.pack_data = pack
	return state

func salvage_door(sid: int, door: DoorData) -> void:
	if sid < 0 or sid > 999:
		return
	if salvaged_doors.size() < sid + 1:
		salvaged_doors.resize(sid + 1)
	salvaged_doors[sid] = door
	save()

func get_completed_levels_count() -> int:
	return completed_levels.size()

func get_salvaged_doors_count() -> int:
	return salvaged_doors.reduce(func(accum, door):
		return accum + (1 if door else 0)
	, 0)

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
	if not pack_data.levels_by_id.has(current_level):
		printerr("State's current level doesn't exist: ", String.num_uint64(current_level, 16))
		current_level = pack_data.levels[0].unique_id
	for id in exit_levels:
		if not pack_data.levels_by_id.has(id):
			printerr("Invalid level on exit stack: ", String.num_uint64(id, 16))

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

func erase() -> void:
	delete_file()
	pack_data.state_data = make_from_pack_data(pack_data)
	# HACK
	Global.current_level.reset()

func delete_file() -> void:
	var file_path := get_path_from_pack(pack_data)
	DirAccess.remove_absolute(file_path)

static func pr(s: String) -> void:
	if SHOULD_PRINT:
		print(s)
