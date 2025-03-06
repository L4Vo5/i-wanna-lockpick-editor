@tool
extends Resource
class_name CounterPartData

@export var color := Enums.Colors.None

# visual settings

## position in door
@export var position := 0:
	set(val):
		if position == val: return
		position = val
		changed.emit()
		
## Variables modified by the door data for easier rendering. Not meant to be stored, but I guess they can be used for logic?
var glitch_color := Enums.Colors.Glitch

## used if the door's count doesn't align with the i-view status
var is_starred := false:
	set(val):
		if is_starred == val: return
		is_starred = val
		changed.emit()

func duplicated() -> CounterPartData:
	var lock := CounterPartData.new()
	lock.color = color
	lock.position = position
	return lock

func get_used_color() -> Enums.Colors:
	var used_color := color
	return used_color

func check_valid(level_data: LevelData, should_correct: bool) -> bool:
	var is_valid := true
	if color == Enums.Colors.None:
		level_data.add_invalid_reason("Counter has none color", false)
		is_valid = false
	return is_valid
