extends Resource
class_name LevelPackStateData
## The state of a level pack. Also doubles as save data.

static var SHOULD_PRINT := false

var file_path: String = ""

## Id of the pack this state data corresponds to (used for save data)
@export var pack_id: int

## The actual pack data (might be briefly null when loading save data)
var pack_data: LevelPackData:
	set(val):
		if val == pack_data: return
		disconnect_pack_data()
		pack_data = val
		connect_pack_data()

## State name in case of multiple save files
@export var state_name: String = ""

## An array with the completion status of each level (0: incomplete, 1: completed)
# A level is completed when you reach the goal.
@export var completed_levels: PackedByteArray

## The salvaged doors. Their origin doesn't matter.
@export var salvaged_doors: Array[DoorData] = []

## The current level that's being played in the pack.
@export var current_level: int

## The level that you reach when exiting (backspace).
@export var exit_level: int = -1

## The player position within exit_level after exiting
@export var exit_position: Vector2i

static func make_from_pack_data(pack: LevelPackData) -> LevelPackStateData:
	var state := LevelPackStateData.new()
	state.completed_levels = PackedByteArray()
	state.completed_levels.resize(pack.levels.size())
	state.pack_id = pack.pack_id
	state.pack_data = pack
	return state

func connect_pack_data() -> void:
	if !pack_data: return
	pack_data.state_data = self
	pack_data.added_level.connect(_on_added_level)
	pack_data.deleted_level.connect(_on_deleted_level)
	assert(pack_data.levels.size() == completed_levels.size())

func disconnect_pack_data() -> void:
	if !pack_data: return
	pack_data.added_level.disconnect(_on_added_level)
	pack_data.deleted_level.disconnect(_on_deleted_level)

func salvage_door(sid: int, door: DoorData) -> void:
	if sid < 0 || sid > 999:
		return
	if salvaged_doors.size() < sid + 1:
		salvaged_doors.resize(sid + 1)
	salvaged_doors[sid] = door
	save()

func _on_added_level() -> void:
	assert(pack_data.levels.size() == completed_levels.size() + 1)
	completed_levels.resize(pack_data.levels.size())
	save()

func _on_deleted_level(level_id: int) -> void:
	assert(pack_data.levels.size() == completed_levels.size() - 1)
	completed_levels.remove_at(level_id)
	assert(pack_data.levels.size() == completed_levels.size())
	# TODO: also sort out salvages I guess
	save()

func save() -> void:
	if not pack_data.is_pack_id_saved:
		return
	if file_path == "":
		var dir = "user://level_saves"
		var original_path = dir.path_join(str(pack_id))
		if not FileAccess.file_exists(original_path + ".lvlst"):
			file_path = original_path + ".lvlst"
		else:
			var i := 1
			while FileAccess.file_exists(original_path + "-" + str(i) + ".lvlst"):
				i += 1
			file_path = original_path + "-" + str(i) + ".lvlst"
		pr("Save data path: " + file_path)
	SaveLoad.save_pack_state(self)

static func load_and_check_pack_state(path, pack) -> LevelPackStateData:
	if path.ends_with(".tres"):
		var state := ResourceLoader.load(path)
		if not state or not state is LevelPackStateData or not state.pack_id == pack.pack_id:
			return null
		return state
	var state := SaveLoad.load_and_check_pack_state_from_path(path, pack)
	if state == null:
		return null
	state.file_path = path
	return state

static func find_state_file_for_pack_or_create_new(pack: LevelPackData) -> LevelPackStateData:
	var state: LevelPackStateData = null
	var prefix: String = str(pack.pack_id)
	for file_name in DirAccess.get_files_at("user://level_saves"):
		if not file_name.begins_with(prefix):
			# shouldn't belong to this level pack
			continue
		# try reading the file
		var path := "user://level_saves".path_join(file_name)
		state = load_and_check_pack_state(path, pack)
		if state != null:
			break
	if not state:
		state = LevelPackStateData.make_from_pack_data(pack)
		state.save()
		pr("Couldn't find save data, making a new one *eventually*")
	else:
		pr("Successfully loaded save data from %s!" % state.file_path)
	return state

static func pr(s: String) -> void:
	if SHOULD_PRINT:
		print(s)
