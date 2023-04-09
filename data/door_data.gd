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
@export var sequence_next: Array[DoorData] = []
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

func set_curse(curse: Enums.curse, val: bool) -> void:
	if _curses[curse] == val: return
	_curses[curse] = val
	changed.emit()

func get_curse(curse: Enums.curse) -> bool:
	return _curses[curse]

func _init() -> void:
	amount.changed.connect(emit_changed)

func duplicated() -> DoorData:
	var dupe := DoorData.new()
	dupe.outer_color = outer_color
	dupe.size = size
	dupe.position = position
	dupe._curses = _curses.duplicate()
	dupe.amount = amount.duplicate(true)
	for l in locks:
		dupe.locks.push_back(l.duplicated())
	for seq in sequence_next:
		dupe.sequence_next.push_back(seq)
	return dupe

func has_point(point: Vector2) -> bool:
	return Rect2(position, size).has_point(point)

## try to open the door with the current level's keys.
## returns true if the door opened.
## (also tries changing the door's count)
func try_open() -> Dictionary:
	var return_dict := {
		"opened" = false,
		"master_key" = false,
		"added_copy" = false, # can only happen with master keys
	}
	if amount.is_zero(): return return_dict
	if _curses[Enums.curse.ice] or _curses[Enums.curse.erosion] or _curses[Enums.curse.paint]: return return_dict
	var player: Kid = Global.current_level.player
	# try to open with master keys
	if not player.master_equipped.is_zero():
		var can_master := true
		var non_copiable_colors := [Enums.colors.master, Enums.colors.pure]
		if glitch_color in non_copiable_colors:
			non_copiable_colors.push_back(Enums.colors.glitch)
		if _curses[Enums.curse.brown]:
			can_master = true
		elif outer_color in non_copiable_colors:
			can_master = false
		else:
			for lock in locks:
				if lock.color in non_copiable_colors:
					can_master = false
					break
		if can_master:
			return_dict.master_key = true
			var old_amount := amount.duplicate()
			amount.sub(player.master_equipped)
			if amount.is_bigger_than(old_amount):
				return_dict.added_copy = true
			if not Global.current_level.star_keys[Enums.colors.master]:
				Global.current_level.key_counts[Enums.colors.master].sub(player.master_equipped)
			if not Input.is_action_pressed(&"master"):
				if not player.master_equipped.is_zero():
					player.update_master_equipped(true, false)
			return_dict.opened = true
			return return_dict
	# open normally
	var diff := ComplexNumber.new()
	var i_view: bool = Global.current_level.i_view if is_instance_valid(Global.current_level) else false
	var open_dim := ComplexNumber.new()
	var rotor := false
	var flip := false
	if amount.real_part > 0:
		open_dim.set_to(1, 0)
	elif amount.real_part < 0:
		open_dim.set_to(-1, 0)
		flip = true
	if i_view or amount.real_part == 0:
		if amount.imaginary_part > 0:
			open_dim.set_to(0, 1)
			rotor = true
			flip = false
		elif amount.imaginary_part < 0:
			open_dim.set_to(0, -1)
			rotor = true
			flip = false
		elif not i_view: # just in case idk
			assert(amount.is_zero(), "what??")
			printerr("Can't open a door with 0 copies!")
	
	for lock_data in locks:
		var color_amount: ComplexNumber = Global.current_level.key_counts[lock_data.color]
		var diff_after_open := lock_data.open_with(color_amount, flip, rotor)
		if diff_after_open == null: return return_dict
		diff.add(diff_after_open)
	# it worked on all locks!
	amount.sub(open_dim)
	if not Global.current_level.star_keys[outer_color]:
		Global.current_level.key_counts[outer_color].add(diff)
	Global.current_level.glitch_color = outer_color
	return_dict.opened = true
	return return_dict


func has_color(color: Enums.colors) -> bool:
	if outer_color == color:
		return true
	for lock in locks:
		if lock.color == color:
			return true
	return false
