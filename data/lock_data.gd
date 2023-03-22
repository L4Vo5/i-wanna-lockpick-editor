@tool
extends Resource
class_name LockData

@export var color := Enums.colors.none:
	set(val):
		if color == val: return
		color = val
		changed.emit()
@export var magnitude := 0:
	set(val):
		if magnitude == val: return
		magnitude = val
		changed.emit()
@export var sign := Enums.sign.positive:
	set(val):
		if sign == val: return
		sign = val
		changed.emit()
@export var value_type := Enums.value.real:
	set(val):
		if value_type == val: return
		value_type = val
		changed.emit()
@export var lock_type := lock_types.normal:
	set(val):
		if lock_type == val: return
		lock_type = val
		changed.emit()

# visual settings
## displayed size
@export var size := Vector2(18, 18):
	set(val):
		if size == val: return
		size = val
		changed.emit()
## position in door
@export var position := Vector2(7, 7):
	set(val):
		if position == val: return
		position = val
		changed.emit()
## the lock pattern to use, or -1 for numbers
## (nonexistent arrangements will default to numbers too)
@export var lock_arrangement := 0:
	set(val):
		if lock_arrangement == val: return
		lock_arrangement = val
		changed.emit()
## if rendering as number, don't show the lock symbol
@export var dont_show_lock := false:
	set(val):
		if dont_show_lock == val: return
		dont_show_lock = val
		changed.emit()

## Variables modified by the door data for easier rendering. Not meant to be stored, but I guess they can be used for logic?
signal changed_glitch
var glitch_color := Enums.colors.glitch:
	set(val):
		if glitch_color == val: return
		glitch_color = val
		changed_glitch.emit()

signal changed_override_brown
var override_brown := false:
	set(val):
		if override_brown == val: return
		override_brown = val
		changed_override_brown.emit()

signal changed_dont_show_frame
## used if the door's count doesn't align with the i-view status, also hides locks (couldn't think of a good name that includes that)
var dont_show_frame := false:
	set(val):
		if dont_show_frame == val: return
		dont_show_frame = val
		changed_dont_show_frame.emit()

signal changed_rotation
## rotation for rendering i-view and negative doors
var rotation := ComplexNumber.new_with(1, 0):
	set(val):
		if is_instance_valid(rotation):
			if rotation.changed.is_connected(emit_changed):
				rotation.changed.disconnect(emit_changed)
		if rotation == val: return
		rotation = val
		if is_instance_valid(rotation):
			rotation.changed.connect(emit_changed)
		changed_rotation.emit()

func _init() -> void:
	rotation = rotation.duplicate()

enum lock_types {
	normal,
	blast,
	blank, # will ignore value_type and sign_type
	all, # will ignore value_type and sign_type
}

# I can't believe I made this lmao??? fine tho
const value_type_to_ComplexNumber_var: Dictionary = {
	Enums.value.real: &"real_part",
	Enums.value.imaginary: &"imaginary_part",
}
# returns the key count difference after opening, or null if it can't be opened
func open_with(key_count: ComplexNumber, flipped: bool, is_rotor: bool) -> ComplexNumber:
	# listen... it works lmao
	if flipped or is_rotor:
		var temp_lock: LockData = duplicate(true)
		if flipped:
			temp_lock.flip_sign()
		if is_rotor:
			temp_lock.rotor()
		return temp_lock.open_with(key_count, false, false)
	
	if lock_type == lock_types.all:
		if key_count.real_part == 0 and key_count.imaginary_part == 0:
			return null
		else:
			return key_count.duplicate().flip()
	if lock_type == lock_types.blank:
		if key_count.real_part != 0 or key_count.imaginary_part != 0:
			return null
		else:
			return ComplexNumber.new()
	
	var new_key_count := ComplexNumber.new()
	var signed_magnitude := magnitude if sign == Enums.sign.positive else -magnitude
	var relevant_value_sn: StringName = value_type_to_ComplexNumber_var[value_type]
	var relevant_value = key_count.get(relevant_value_sn)
	
	if abs(relevant_value) < magnitude or signi(relevant_value) != signi(signed_magnitude):
		return null
	
	match lock_type:
		lock_types.normal:
			new_key_count.set(relevant_value_sn, -signed_magnitude)
		lock_types.blast:
			new_key_count.set(relevant_value_sn, -relevant_value)
	
	return new_key_count

## no-nonsense returns the lockdata's amount as a complex number
func get_complex_amount() -> ComplexNumber:
	var val := magnitude
	if sign == Enums.sign.negative: val *= -1
	var num := ComplexNumber.new()
	if value_type == Enums.value.real:
		num.real_part = val
	else:
		num.imaginary_part = val
	return num

const flip_sign_dict := {
	Enums.sign.positive: Enums.sign.negative,
	Enums.sign.negative: Enums.sign.positive,
}
## should be useful for the editor
func flip_sign() -> LockData:
	sign = flip_sign_dict[sign]
	return self

const rotor_dict_value = {
	Enums.value.real: Enums.value.imaginary,
	Enums.value.imaginary: Enums.value.real,
}
## should be useful for the editor
func rotor() -> LockData:
	value_type = rotor_dict_value[value_type]
	if value_type == Enums.value.real:
		flip_sign()
	return self
