@tool
extends Resource
class_name DoorData

## Contains a door's logical data

# amount for each universe
@export var amount := [ComplexNumber.new_with(1, 0)]
@export var outer_color := Enums.color.none
@export var locks: Array[LockData] = []
@export var sequence_next: Array[DoorData] = []
@export var size := Vector2i(32, 32)
@export var curses := {
	Enums.curses.ice: false,
	Enums.curses.eroded: false,
	Enums.curses.painted: false,
	Enums.curses.brown: false,
}

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
