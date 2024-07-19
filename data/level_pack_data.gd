extends Resource
class_name LevelPackData

signal added_level(level_id: int)
signal deleted_level(level_id: int)
signal swapped_levels(level_1_index: int, level_2_index: int)
signal moved_level(from: int, to: int)

## levels indexed by id
@export var levels := {}
## levels ordered by id
@export var level_order: PackedInt32Array
## used internally. level ids are sure to fit in 16 bits
var _next_level_id: int = 0

# TODO: max length for these fields?
## Name of the level pack, important when picking what to play
@export var name: String
## Author or authors, important to know who made things!
@export var author: String
## Description of the level pack, displayed in level selection
@export var description: String
## Pack id, this SHOULD be unique.
# "& ~(1<<63)" ensures it's not negative
@export var pack_id: int = (randi() << 32) + randi() & ~(1<<63)

## If empty, the pack will have to be saved as a new file.
var file_path := "":
	set(val):
		if file_path == val: return
		file_path = val
		changed.emit()

## Make a LevelPackData from a single level data (to have a "level pack" that's just one level)
## Useful because .lvl files used to be a single level
static func make_from_level(level_data: LevelData) -> LevelPackData:
	var data := LevelPackData.new()
	data.name = level_data.name
	data.author = level_data.author
	var level_dupe := level_data.duplicated()
	level_dupe.resource_path = ""
	data.add_level(level_dupe)
	return data

static func get_default_level_pack() -> LevelPackData:
	var level := LevelData.get_default_level()
	var pack := LevelPackData.new()
	pack.add_level(level)
	return pack

# Only the keys are used. values are true for fixable and false for unfixable
var _fixable_invalid_reasons := {}
var _unfixable_invalid_reasons := {}

func get_fixable_invalid_reasons() -> Array:
	return _fixable_invalid_reasons.keys()

func get_unfixable_invalid_reasons() -> Array:
	return _unfixable_invalid_reasons.keys()

func check_valid(should_correct: bool) -> void:
	_fixable_invalid_reasons = {}
	_unfixable_invalid_reasons = {}
	if level_order.size() != levels.size():
		# I'll mark it unfixable for now
		_unfixable_invalid_reasons[&"level order size doesn't match levels size"] = true
	for level: LevelData in levels.values():
		level.check_valid(should_correct)
		for reason in level.get_fixable_invalid_reasons():
			_fixable_invalid_reasons[reason] = true
		for reason in level.get_unfixable_invalid_reasons():
			_unfixable_invalid_reasons[reason] = false

## returns a level by their position in the ordered list
func get_level_by_position(position: int) -> LevelData:
	var id := level_order[position]
	return levels[id]

## returns a level's position (index) in the ordered list given its id, or -1 if it doesn't exist
func get_level_position_by_id(id: int) -> int:
	return level_order.find(id)

## Ideally don't use this, but it's an easy replacement for old code, and i guess the most comfortable way to iterate the levels?? unfortunate. perhaps this should be its own variable
func get_levels_ordered() -> Array[LevelData]:
	var arr: Array[LevelData] = []
	arr.resize(levels.size())
	for position in level_order:
		arr.push_back(get_level_by_position(position))
	return arr

# yes, infinite loop if you have 65535 levels and add another.
# but I'd say that's your own damn fault.
func get_next_level_id() -> int:
	while levels.has(_next_level_id):
		_next_level_id += 1
		if _next_level_id >= (1 << 16):
			_next_level_id -= 1 << 16
	return _next_level_id

func add_level(new_level: LevelData, position := -1) -> void:
	if position == -1:
		position = levels.size()
	var id := get_next_level_id()
	levels[id] = new_level
	var err := level_order.insert(position, id)
	assert(err == OK)
	added_level.emit(id)
	emit_changed()

func duplicate_level(id: int) -> void:
	var index := get_level_position_by_id(id)
	add_level(levels[id].duplicated(), index)

func delete_level(id: int) -> void:
	assert(levels.has(id))
	levels.erase(id)
	level_order.remove_at(level_order.find(id))
	deleted_level.emit(id)
	emit_changed()

## This takes in indices in the ordered array, since that's the only thing you care about when swapping.
func swap_levels(index_1: int, index_2: int) -> void:
	# swap
	var id_1 := level_order[index_1]
	level_order[index_1] = level_order[index_2]
	level_order[index_2] = id_1
	swapped_levels.emit(index_1, index_2)
	emit_changed()

## Moves the level at index `from` to the index `to`, shifting everything in between. [br]
## This takes in indices in the ordered array, since that's the only thing you care about when moving.
func move_level(from: int, to: int) -> void:
	if to == from:
		return
	var level_data := level_order[from]
	level_order.remove_at(from)
	level_order.insert(to, level_data)
	moved_level.emit(from, to)
	emit_changed()
