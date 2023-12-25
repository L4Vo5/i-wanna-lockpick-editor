extends Resource
class_name LevelPackData

@export var levels: Array[LevelData]
@export var editor_version: String
@export var name: String
@export var author: String

## For easier saving, since resource_path probably wouldn't work with .lvl
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
	data.editor_version = level_data.editor_version
	data.levels = [level_data.duplicate()]
	data.levels[0].resource_path = ""
	return data

# Only the keys are used. values are true for fixable and false for unfixable
var _fixable_invalid_reasons := {}
var _unfixable_invalid_reasons := {}

# WAITING4GODOT: these can't be Array[String] ... ?
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
