@tool
extends Resource
class_name SalvagePointData

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
	if is_output && door_error:
		s += "\n!!! Not Enough Space !!!"
	return s

func get_rect() -> Rect2i:
	return Rect2i(position, Vector2i(32, 32))
