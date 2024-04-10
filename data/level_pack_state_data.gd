extends Resource
class_name LevelPackStateData
## The state of a level pack. Also doubles as save data.

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
	if resource_path != "":
		var res := ResourceSaver.save(self)
		if res != OK:
			print("Couldn't save! Error:" + error_string(res))
	else:
		print("Couldn't save! no resource_path!")

static func find_state_file_for_pack_or_create_new(pack: LevelPackData) -> LevelPackStateData:
	var state: LevelPackStateData = null
	var pack_id := pack.pack_id
	for file_name in DirAccess.get_files_at("user://level_saves"):
		var file_path := "user://level_saves".path_join(file_name)
		var possible_state = load(file_path)
		if possible_state is LevelPackStateData:
			if possible_state.pack_id == pack_id:
				state = possible_state
				state.pack_data = pack
	if not state:
		state = LevelPackStateData.make_from_pack_data(pack)
		var i := pack.pack_id
		while FileAccess.file_exists("user://level_saves/" + str(i) + ".tres"):
			i = randi()
		state.resource_path = "user://level_saves/" + str(i) + ".tres"
		state.save()
		print("Couldn't find save data, making a new one at %s" % state.resource_path)
	else:
		print("Successfully loaded save data from %s!" % state.resource_path)
	return state
