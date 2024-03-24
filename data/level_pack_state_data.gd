extends Resource
class_name LevelPackStateData
## The state of a level pack. Also doubles as save data.

## Id of the pack this state data corresponds to (used for save data)
@export var pack_id: int

## The actual pack data (might be briefly null when loading save data)
var pack_data: LevelPackData

## An array with the completion status of each level (0: incomplete, 1: completed)
# A level is completed when you reach the goal.
@export var completed_levels: PackedByteArray

## The salvaged doors. Their origin doesn't matter.
@export var salvaged_doors: Array[DoorData] = []

## The current level that's being played in the pack.
@export var current_level: int

static func make_from_pack_data(pack: LevelPackData) -> LevelPackStateData:
	var state := LevelPackStateData.new()
	state.pack_data = pack
	state.pack_id = pack.pack_id
	state.completed_levels = PackedByteArray()
	state.completed_levels.resize(pack.levels.size())
	return state



