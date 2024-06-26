extends Resource
class_name LevelPackData

signal added_level(level_id: int)
signal deleted_level(level_id: int)
signal swapped_levels(level_1_id: int, level_2_id: int)
## All the levels in the level pack
@export var levels: Array[LevelData]

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

## For simplicity, each pack data has one state associated with it.
var state_data: LevelPackStateData:
	set(val):
		state_data = val
		changed.emit()

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
	data.levels = [level_data.duplicated()]
	data.levels[0].resource_path = ""
	return data

static func get_default_level_pack() -> LevelPackData:
	var level := LevelData.get_default_level()
	var pack := LevelPackData.new()
	pack.levels.push_back(level)
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
	for level in levels:
		level.check_valid(should_correct)
		for reason in level.get_fixable_invalid_reasons():
			_fixable_invalid_reasons[reason] = true
		for reason in level.get_unfixable_invalid_reasons():
			_unfixable_invalid_reasons[reason] = false

func add_level(new_level: LevelData, id: int) -> void:
	var err := levels.insert(id, new_level)
	assert(err == OK)
	# No need to do this if you added a level at the very end.
	if id != levels.size():
		for level in levels:
			for entry in level.entries:
				if entry.leads_to >= id:
					entry.leads_to += 1
	added_level.emit(id)
	emit_changed()

func duplicate_level(id: int) -> void:
	add_level(levels[id].duplicated(), id + 1)

func delete_level(id: int) -> void:
	levels.remove_at(id)
	for level in levels:
		for entry in level.entries:
			if entry.leads_to > id:
				entry.leads_to -= 1
			elif entry.leads_to == id:
				entry.leads_to = -1
	deleted_level.emit(id)
	emit_changed()

func swap_levels(id_1: int, id_2: int) -> void:
	# swap
	var l := levels[id_1]
	levels[id_1] = levels[id_2]
	levels[id_2] = l
	# correct the entries
	for level in levels:
		for entry in level.entries:
			if entry.leads_to == id_1:
				entry.leads_to = id_2
			elif entry.leads_to == id_2:
				entry.leads_to = id_1
	swapped_levels.emit(id_1, id_2)
	emit_changed()
