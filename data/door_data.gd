@tool
extends Resource
class_name DoorData

## Contains a door's logical data

@export var amount := ComplexNumber.new_with(1, 0):
	set(val):
		if amount == val: return
		if is_instance_valid(amount):
			if amount.changed.is_connected(emit_changed):
				amount.changed.disconnect(emit_changed)
		amount = val
		amount.changed.connect(emit_changed)
		changed.emit()

@export var outer_color := Enums.colors.none:
	set(val):
		if outer_color == val: return
		outer_color = val
		changed.emit()
# Please don't push_back on these or anything!! use add_lock or remove_lock
@export var locks: Array[LockData] = []:
	set(val):
		if locks == val: return
		for l in locks:
			if is_instance_valid(l):
				l.changed.disconnect(emit_changed)
		locks = val
		for l in locks:
			if is_instance_valid(l):
				l.changed.connect(emit_changed)
		changed.emit()

@export var size := Vector2i(32, 32):
	set(val):
		if size == val: return
		size = val
		changed.emit()
@export var _curses := {
	Enums.curse.ice: false,
	Enums.curse.erosion: false,
	Enums.curse.paint: false,
	Enums.curse.brown: false,
}
@export var glitch_color := Enums.colors.glitch:
	set(val):
		if glitch_color == val: return
		glitch_color = val
		for lock in locks:
			lock.glitch_color = glitch_color
		changed.emit()
@export var position := Vector2i(0, 0):
	set(val):
		if position == val: return
		position = val
		changed.emit()

func add_lock(lock: LockData) -> void:
	locks.push_back(lock)
	lock.changed.connect(emit_changed)
	changed.emit()

func remove_lock_at(pos: int) -> void:
	locks[pos].changed.disconnect(emit_changed)
	locks.remove_at(pos)
	changed.emit()

func set_curse(curse: Enums.curse, val: bool, register_undo := false) -> void:
	if _curses[curse] == val: return
	if outer_color == Enums.colors.gate:
		return
	if curse == Enums.curse.brown:
		if has_color(Enums.colors.pure):
			return
		# Can't curse completely brown doors (doesn't matter either way)
		if outer_color == Enums.colors.brown\
				and locks.all(func(l: LockData) -> bool:
					return l.color == Enums.colors.brown):
			return
		for lock in locks:
			lock.is_cursed = val
	var level: Level = Global.current_level
	if register_undo:
		level.start_undo_action()
		level.undo_redo.add_do_method(set_curse.bind(curse, val))
		level.undo_redo.add_undo_method(set_curse.bind(curse, _curses[curse]))
		level.end_undo_action()
	_curses[curse] = val
	changed.emit()

func get_curse(curse: Enums.curse) -> bool:
	return _curses[curse]

func _init() -> void:
	amount.changed.connect(emit_changed)

func duplicated() -> DoorData:
#	assert(PerfManager.start("DoorData::duplicated"))
	var dupe := DoorData.new()
	dupe.outer_color = outer_color
	dupe.size = size
	dupe.position = position
	dupe._curses = _curses.duplicate()
	dupe.amount = amount.duplicated()
	
#	assert(PerfManager.start("DoorData::duplicated (locks)"))
	for l in locks:
		dupe.locks.push_back(l.duplicated())
#	assert(PerfManager.end("DoorData::duplicated (locks)"))
#	assert(PerfManager.end("DoorData::duplicated"))
	return dupe

func has_point(point: Vector2i) -> bool:
	return Rect2i(position, size).has_point(point)

func get_rect() -> Rect2i:
	return Rect2i(position, size)

const NON_COPIABLE_COLORS := [Enums.colors.master, Enums.colors.pure]
## try to open the door with the current level's keys.
## returns true if the door opened.
## (also tries changing the door's count)
func try_open() -> Dictionary:
	var return_dict := {
		&"opened": false,
		&"master_key": false,
		&"added_copy": false, # can only happen with master keys
		&"do_methods": [],
		&"undo_methods": [],
	}
	if amount.is_zero(): return return_dict
	if _curses[Enums.curse.ice] or _curses[Enums.curse.erosion] or _curses[Enums.curse.paint]: return return_dict
	
	var used_outer_color := get_used_color()
	var is_gate := outer_color == Enums.colors.gate
	
	var level: Level = Global.current_level
	var player: Kid = level.player
	
	# try to open with master keys
	if not is_gate and not player.master_equipped.is_zero():
		var can_master := true
		if used_outer_color in NON_COPIABLE_COLORS:
			can_master = false
		else:
			for lock in locks:
				if lock.get_used_color() in NON_COPIABLE_COLORS:
					can_master = false
					break
		if can_master:
			return_dict.master_key = true
			return_dict.undo_methods.push_back(amount.set_to.bind(amount.real_part, amount.imaginary_part))
			var old_amount := amount.duplicated()
			amount.sub(player.master_equipped)
			return_dict.do_methods.push_back(amount.set_to.bind(amount.real_part, amount.imaginary_part))
			if amount.is_bigger_than(old_amount):
				return_dict.added_copy = true
			if not level.star_keys[Enums.colors.master]:
				var count: ComplexNumber = level.key_counts[Enums.colors.master]
				return_dict.undo_methods.push_back(count.set_to.bind(count.real_part, count.imaginary_part))
				count.sub(player.master_equipped)
				return_dict.do_methods.push_back(count.set_to.bind(count.real_part, count.imaginary_part))
			if not Input.is_action_pressed(&"master"):
				if not player.master_equipped.is_zero():
					player.update_master_equipped(true, false)
			return_dict.opened = true
			return return_dict
	
	# open normally
	var i_view: bool = level.i_view
	var open_dim := ComplexNumber.new_with(1, 0)
	
	# when there's both real and imaginary copies, it should try opening the door twice, first for the currently-focused one (real if no i-view, imaginary if i-view)
	# but also, even the currently-focused one should be skipped if there are 0 copies 
	# so this variable dictates, for real and then imaginary copies: [should it even try?, should it rotor the locks?, should it flip them?]
	var dims_try_rotor_flip := [
		[amount.real_part != 0, false, amount.real_part < 0],
		[amount.imaginary_part != 0, true, amount.imaginary_part < 0]]
	
	if i_view: # if i-view, try imaginary copies first
		dims_try_rotor_flip.reverse()
	
	var diff: ComplexNumber
	var did_it_open: bool
	for try_rotor_flip in dims_try_rotor_flip:
		var try: bool = try_rotor_flip[0]
		var rotor: bool = try_rotor_flip[1]
		var flip: bool = try_rotor_flip[2]
		if not try: continue
		diff = ComplexNumber.new_with(0, 0)
		did_it_open = true
		for lock_data in locks:
			var used_lock_color := lock_data.get_used_color()
			
			var key_amount: ComplexNumber = level.key_counts[used_lock_color]
			var diff_after_open := lock_data.open_with(key_amount, flip, rotor)
			# open_with returns null if it couldn't be opened
			if diff_after_open == null:
				did_it_open = false
				break
			diff.add(diff_after_open)
		if did_it_open: # it worked for the first dimension, don't try again
			if rotor:
				open_dim.rotor()
			if flip:
				open_dim.flip()
			break
	
	if not did_it_open: return return_dict
	# it worked on all locks!
	if not is_gate:
		return_dict.undo_methods.push_back(amount.set_to.bind(amount.real_part, amount.imaginary_part))
		amount.sub(open_dim)
		return_dict.do_methods.push_back(amount.set_to.bind(amount.real_part, amount.imaginary_part))
	
		if not level.star_keys[used_outer_color]:
			var count: ComplexNumber = level.key_counts[used_outer_color]
			return_dict.undo_methods.push_back(count.set_to.bind(count.real_part, count.imaginary_part))
			count.add(diff)
			return_dict.do_methods.push_back(count.set_to.bind(count.real_part, count.imaginary_part))
		if level.glitch_color != used_outer_color:
			return_dict.undo_methods.push_back(level.set.bind(&"glitch_color", level.glitch_color))
			level.glitch_color = used_outer_color
			return_dict.undo_methods.push_back(level.set.bind(&"glitch_color", used_outer_color))
	return_dict.opened = true
	return return_dict

# Called by the actual in-level Door
func update_glitch_color(color: Enums.colors) -> void:
	if not get_curse(Enums.curse.brown):
		glitch_color = color

func has_color(color: Enums.colors) -> bool:
	if get_used_color() == color:
		return true
	for lock in locks:
		if lock.get_used_color() == color:
			return true
	return false

func get_used_color() -> Enums.colors:
	var used_color := outer_color
	if get_curse(Enums.curse.brown):
		used_color = Enums.colors.brown
	elif used_color == Enums.colors.glitch:
		used_color = glitch_color
	return used_color

func check_valid(level_data: LevelData, should_correct: bool) -> bool:
	var is_valid := true
	if amount.is_zero():
		level_data.add_invalid_reason("Door has count 0", true)
		is_valid = is_valid and should_correct
		if should_correct:
			amount.set_real_part(1)
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
	if outer_color == Enums.colors.gate:
		s = "Gate"
	else:
		s = Enums.COLOR_NAMES[outer_color].capitalize() + " Door"
	s += "\n"
	for lock in locks:
		if lock.lock_type != Enums.lock_types.normal:
			s += Enums.LOCK_TYPE_NAMES[lock.lock_type].capitalize() + " "
		s += Enums.COLOR_NAMES[lock.color].capitalize()
		s += " Lock"
		if lock.lock_type == Enums.lock_types.normal:
			s += ", Cost: "
			s += str(lock.get_complex_amount())
		elif lock.lock_type == Enums.lock_types.blast:
			var part := ""
			if lock.sign == Enums.sign.positive:
				part = "+"
			else:
				part = "-"
			if lock.value_type == Enums.value.imaginary:
				part += "i"
			s += ", Cost: [All %s]" % part
		s += "\n"
	if outer_color == Enums.colors.glitch or locks.any(func(lock): return lock.color == Enums.colors.glitch):
		s += "Mimic: " + Enums.COLOR_NAMES[glitch_color].capitalize()
		s += "\n"
	if not amount.is_equal_to(ComplexNumber.new_with(1, 0)):
		s += "Copies: " + str(amount)
		s += "\n"
	return s
