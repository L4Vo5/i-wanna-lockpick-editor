@tool
extends Resource
class_name CounterPartData

@export var color := Enums.Colors.None

func duplicated() -> CounterPartData:
	var counter_part := CounterPartData.new()
	counter_part.color = color
	return counter_part

func check_valid(level_data: LevelData, should_correct: bool) -> bool:
	var is_valid := true
	if color == Enums.Colors.None:
		level_data.add_invalid_reason("Counter has none color", false)
		is_valid = is_valid and should_correct
		if should_correct:
			color = Enums.Colors.White
	return is_valid
