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

