@tool
extends Resource
class_name SalvagePointData

static var level_element_type := Enums.LevelElementTypes.SalvagePoint

@export var sid := 0:
	set(val):
		if sid == val: return
		sid = val
		emit_changed()

@export var is_output := false:
	set(val):
		if is_output == val: return
		is_output = val
		emit_changed()

@export var position := Vector2i(0, 0):
	set(val):
		if position == val: return
		position = val
		emit_changed()

func duplicated() -> SalvagePointData:
	var dupe := SalvagePointData.new()
	dupe.sid = sid
	dupe.is_output = is_output
	dupe.position = position
	return dupe

func get_mouseover_text(door_error) -> String:
	var s := ""
	if is_output:
		s += "Output Point"
	else:
		s += "Input Point"
	s += "\n\n"
	s += "SID: " + str(sid)
	if is_output and door_error:
		s += "\n!!! Not Enough Space !!!"
	return s

func get_rect() -> Rect2i:
	return Rect2i(position, Vector2i(32, 32))

func check_valid(level_data: LevelData, should_correct: bool) -> bool:
	var is_valid := true
	if sid < -1:
		is_valid = is_valid and should_correct
		level_data.add_invalid_reason("SID too low (%d)" % sid, true)
		if should_correct:
			sid = -1
	if sid > 999:
		is_valid = is_valid and should_correct
		level_data.add_invalid_reason("SID too high (%d)" % sid, true)
		if should_correct:
			sid = 999
	return is_valid
