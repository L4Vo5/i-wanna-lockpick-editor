@tool
extends Resource
class_name DoorData

## Contains a door's logical data

# amount for each universe
@export var amount: Array[ComplexNumber] = [ComplexNumber.new_with(1, 0)]:
	set(val):
		if amount == val: return
		for a in amount:
			if is_instance_valid(a):
				a.changed.disconnect(emit_changed)
		amount = val
		for a in amount:
			a.changed.connect(emit_changed)
		changed.emit()
@export var outer_color := Enums.color.none:
	set(val):
		if outer_color == val: return
		outer_color = val
		changed.emit()
@export var locks: Array[LockData] = []:
	set(val):
		if locks == val: return
		for l in locks:
			if is_instance_valid(l):
				l.changed.disconnect(emit_changed)
		locks = val
		for l in locks:
			l.changed.connect(emit_changed)
		changed.emit()
@export var sequence_next: Array[DoorData] = []
@export var size := Vector2i(32, 32):
	set(val):
		if size == val: return
		size = val
		changed.emit()
@export var _curses := {
	Enums.curses.ice: false,
	Enums.curses.eroded: false,
	Enums.curses.painted: false,
	Enums.curses.brown: false,
}
@export var glitch_color := Enums.color.glitch:
	set(val):
		if glitch_color == val: return
		glitch_color = val
		for lock in locks:
			lock.glitch_color = glitch_color
		changed.emit()

func set_curse(curse: Enums.curses, val: bool) -> void:
	if _curses[curse] == val: return
	_curses[curse] = val
	changed.emit()

func get_curse(curse: Enums.curses) -> bool:
	return _curses[curse]

func _init() -> void:
	for a in amount:
		a.changed.connect(emit_changed)

func duplicated() -> DoorData:
	var dupe := DoorData.new()
	dupe.outer_color = outer_color
	dupe.size = size
	dupe._curses = _curses.duplicate()
	dupe.amount = []
	for a in amount:
		dupe.amount.push_back(a.duplicate(true))
	for l in locks:
		dupe.locks.push_back(l.duplicate(true))
	for seq in sequence_next:
		dupe.sequence_next.push_back(seq)
	return dupe

## try to open the door with the current level's keys.
## returns true if the door opened.
func try_open() -> bool:
	var diff := ComplexNumber.new()
	for lock_data in locks:
		var color_amount: ComplexNumber = Global.current_level.key_counts[lock_data.color]
		var diff_after_open := lock_data.open_with(color_amount)
		if diff_after_open == null: return false
		diff.add(diff_after_open)
	# it worked on all locks!
	amount[0].real_part -= 1
	Global.current_level.key_counts[outer_color].add(diff)
	return true

func has_color(color: Enums.color) -> bool:
	if outer_color == color:
		return true
	for lock in locks:
		if lock.color == color:
			return true
	return false
