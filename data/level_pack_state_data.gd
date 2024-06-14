extends Resource
class_name LevelPackStateData
## The state of a level pack. Also doubles as save data.

static var SHOULD_PRINT := true

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

## An array with the completion status of each level (0: incomplete, 1: completed)
# A level is completed when you reach the goal.
@export var completed_levels: PackedByteArray

## The salvaged doors. Their origin doesn't matter.
@export var salvaged_doors: Array[DoorData] = []

## The current level that's being played in the pack.
@export var current_level: int

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
	pr("Saving data...")
	if file_path == "":
		var i := pack_data.pack_id
		while FileAccess.file_exists("user://level_saves/" + String.num_uint64(i, 16) + ".lvlst"):
			i = Global.random_int64()
		file_path = "user://level_saves/" + String.num_uint64(i, 16) + ".lvlst"
	var data := SaveLoad.VC.make_byte_writer()
	data.store_64(pack_id)
	
	# Completed levels
	data.store_uint(pack_state_meta_category.completed_levels)
	data.store_uint(completed_levels.size())
	for b in completed_levels:
		data.store_8(b)
	
	# Salvaged doors
	data.store_uint(pack_state_meta_category.salvaged_doors)
	data.store_uint(salvaged_doors.size())
	for door in salvaged_doors:
		if door == null:
			data.store_8(0)
		else:
			data.store_8(1)
			SaveLoad.VC._save_door(data, door)
	
	# Current level
	data.store_uint(pack_state_meta_category.current_level)
	data.store_uint(current_level)
	
	data.store_uint(pack_state_meta_category._end)
	
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	file.store_buffer(data.get_data())
	file.close()

enum pack_state_meta_category {
	_end = 0,
	completed_levels = 1,
	salvaged_doors = 2,
	current_level = 3,
}

static func load_state_and_test_id(path: String, pack: LevelPackData) -> LevelPackStateData:
	if path.ends_with(".tres"):
		var possible_state = load(path)
		if possible_state is LevelPackStateData:
			if possible_state.pack_id == pack.pack_id:
				possible_state.pack_data = pack
				return possible_state
		return null
	if not path.ends_with(".lvlst"):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	var id := file.get_64()
	if id != pack.pack_id:
		file.close()
		return null
	var state := LevelPackStateData.new()
	state.file_path = path
	state.pack_id = id
	state.completed_levels.resize(pack.levels.size())
	state.pack_data = pack
	var buffer := file.get_buffer(file.get_length() - file.get_position())
	file.close()
	
	var data := SaveLoad.VC.make_byte_reader(buffer)
	while true:
		var category: pack_state_meta_category = data.get_uint()
		if category == pack_state_meta_category._end:
			break
		elif category == pack_state_meta_category.completed_levels:
			var amount := data.get_uint()
			for i in amount:
				if i < state.completed_levels.size():
					state.completed_levels[i] = data.get_u8()
		elif category == pack_state_meta_category.salvaged_doors:
			var amount := data.get_uint()
			state.salvaged_doors.resize(amount)
			for i in amount:
				var is_present := data.get_u8() != 0
				if is_present:
					state.salvaged_doors[i] = SaveLoad.VC._load_door(data)
				else:
					state.salvaged_doors[i] = null
		elif category == pack_state_meta_category.current_level:
			state.current_level = data.get_uint()
		else:
			assert(false, "Error, invalid category %d" % category)
	return state

static func find_state_file_for_pack_or_create_new(pack: LevelPackData) -> LevelPackStateData:
	var state: LevelPackStateData = null
	for file_name in DirAccess.get_files_at("user://level_saves"):
		var path := "user://level_saves".path_join(file_name)
		state = load_state_and_test_id(path, pack)
		if state != null:
			break
	if not state:
		state = LevelPackStateData.make_from_pack_data(pack)
		# Save when needed
		#state.save()
		pr("Couldn't find save data, creating new one")
	else:
		pr("Successfully loaded save data from %s!" % state.file_path)
	return state

static func pr(s: String) -> void:
	if SHOULD_PRINT:
		print(s)
