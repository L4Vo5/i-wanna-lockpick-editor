@tool
extends Resource
class_name DoorData

## Contains a door's logical data

static var level_element_type := Enums.LevelElementTypes.Door

@export var amount := ComplexNumber.new_with(1, 0)

@export var outer_color := Enums.Colors.None

@export var locks: Array[LockData] = []

@export var position := Vector2i(0, 0)

@export var size := Vector2i(32, 32)

@export var _curses := {
	Enums.Curse.Ice: false,
	Enums.Curse.Erosion: false,
	Enums.Curse.Paint: false,
	Enums.Curse.Brown: false,
}

@export var glitch_color := Enums.Colors.Glitch:
	set(val):
		if glitch_color == val: return
		glitch_color = val
		for lock in locks:
			lock.glitch_color = glitch_color
		changed.emit()

# Will only be something while in the level
var sid := -1

func add_lock(lock: LockData) -> void:
	locks.push_back(lock)
	changed.emit()

func remove_lock_at(pos: int) -> void:
	locks.remove_at(pos)
	changed.emit()

func set_curse(curse: Enums.Curse, val: bool) -> void:
	if _curses[curse] == val: return
	if outer_color == Enums.Colors.Gate:
		return
	if curse == Enums.Curse.Brown:
		for lock in locks:
			lock.is_cursed = val
	_curses[curse] = val
	changed.emit()

func get_curse(curse: Enums.Curse) -> bool:
	return _curses[curse]

func duplicated() -> DoorData:
	var dupe := DoorData.new()
	dupe.outer_color = outer_color
	dupe.size = size
	dupe.position = position
	dupe._curses = _curses.duplicate()
	dupe.amount = amount.duplicated()
	dupe.sid = sid
	
	for l in locks:
		dupe.locks.push_back(l.duplicated())
	return dupe

func has_point(point: Vector2i) -> bool:
	return Rect2i(position, size).has_point(point)

func get_rect() -> Rect2i:
	return Rect2i(position, size)

## Returns true if the door has a given color (taking glitch and curses into account)
func has_color(color: Enums.Colors) -> bool:
	if get_used_color() == color:
		return true
	for lock in locks:
		if lock.get_used_color() == color:
			return true
	return false

## gets the actually used outer color of the door
func get_used_color() -> Enums.Colors:
	var used_color := outer_color
	if get_curse(Enums.Curse.Brown):
		used_color = Enums.Colors.Brown
	elif used_color == Enums.Colors.Glitch:
		used_color = glitch_color
	return used_color

func check_valid(level_data: LevelData, should_correct: bool) -> bool:
	var is_valid := true
	if amount.is_zero():
		level_data.add_invalid_reason("Door has count 0", true)
		is_valid = is_valid and should_correct
		if should_correct:
			amount.set_to(1, 0)
	for lock in locks:
		is_valid = is_valid or lock.check_valid(level_data, should_correct)
		# First, constrain to door size
		if lock.size.x > size.x or lock.size.y > size.y:
			level_data.add_invalid_reason("Lock bigger than door", true)
			is_valid = is_valid and should_correct
			if should_correct:
				lock.size = lock.size.clamp(Vector2i.ZERO, size)
		if lock.minimum_size.x > size.x or lock.minimum_size.y > size.y:
			level_data.add_invalid_reason("Lock bigger than door (forced)", false)
			is_valid = false
		# Then, reposition lock as best as possible toward the upper left corner
		var max_pos := size - lock.size.clamp(Vector2i.ZERO, size)
		var new_pos := lock.position.clamp(Vector2i.ZERO, max_pos)
		if new_pos != lock.position:
			level_data.add_invalid_reason("Lock in wrong position", true)
			is_valid = is_valid and should_correct
			if should_correct:
				lock.position = new_pos
	# TODO: better check locks overlapping eachother 
#	if not check_lock_overlaps():
#		level_data.add_invalid_reason("There are overlapping locks", false)
	return is_valid

func check_lock_overlaps() -> bool:
	var rects: Array[Rect2i] = []
	rects.resize(locks.size())
	for i in locks.size():
		rects[i] = Rect2i(locks[i].position, locks[i].size)
	for i in rects.size():
		var r1 := rects[i]
		for j in range(i + 1, rects.size()):
			var r2 := rects[j]
			if r1.intersects(r2):
				return false
	return false

func get_mouseover_text() -> String:
	var s := ""
	
	if amount.has_value(Enums.INT_MAX, 0): s += "Infinite "
	if amount.has_value(0, 1): s += "Imaginary "
	if amount.has_value(0, Enums.INT_MAX): s += "Infinite Imaginary "
	var dont_show_copies := s != ""
	
	if outer_color == Enums.Colors.Gate:
		s += "Gate"
	else:
		s += Enums.Colors.find_key(outer_color) + " Door"
	
	if not dont_show_copies and not amount.has_value(1, 0):
		s += ", Copies: " + str(amount)
	
	s += "\n"
	
	for lock in locks:
		s += "- "
		if lock.lock_type != Enums.LockTypes.Normal:
			s += Enums.LockTypes.find_key(lock.lock_type) + " "
		
		s += Enums.Colors.find_key(lock.color).capitalize()
		s += " Lock"
		
		if lock.lock_type == Enums.LockTypes.Normal:
			if not lock.get_complex_amount().has_value(1, 0):
				s += ", Cost: "
				s += str(lock.get_complex_amount())
		elif lock.lock_type == Enums.LockTypes.Blast:
			var part := ""
			if lock.sign == Enums.Sign.Positive:
				part = "+"
			else:
				part = "-"
			if lock.value_type == Enums.Value.Imaginary:
				part += "i"
			s += ", Cost: [All %s]" % part
		
		s += "\n"
	
	if outer_color == Enums.Colors.Glitch or locks.any(func(lock): return lock.color == Enums.Colors.Glitch):
		s += "Mimic: " + Enums.Colors.find_key(glitch_color).capitalize()
		s += "\n"
	
	var effects_s := ""
	if get_curse(Enums.Curse.Brown):
		effects_s += "Cursed!\n"
	if get_curse(Enums.Curse.Ice):
		effects_s += "Frozen! (1x Red)\n"
	if get_curse(Enums.Curse.Erosion):
		effects_s += "Eroded! (5x Green)\n"
	if get_curse(Enums.Curse.Paint):
		effects_s += "Painted! (3x Blue)\n"
	
	if effects_s != "":
		s += "~ Effects ~\n"
		s += effects_s
	if sid != -1:
		s += "\nSID: "
		s += str(sid)
		s += "\n"
	return s
