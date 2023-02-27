@tool
extends Resource
class_name LockData

@export var color := Enums.color.none:
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
@export var size := Vector2(18, 18)
## position in door
@export var position := Vector2(7, 7)
## the lock pattern to use, or -1 for numbers
## (nonexistent arrangements will default to numbers too)
@export var lock_arrangement := -1
## if rendering as number, don't show the lock symbol
@export var dont_show_lock := false

enum lock_types {
	normal,
	blast,
	blank, # will ignore value_type and sign_type
	all, # will ignore value_type and sign_type
}

func can_open_with(key_count: ComplexNumber) -> bool:
	return open_with(key_count) != null

const value_type_to_ComplexNumber_var: Dictionary = {
	Enums.value.real: &"real_part",
	Enums.value.imaginary: &"imaginary_part",
}
# returns the key count difference after opening, or null if it can't be opened
func open_with(key_count: ComplexNumber) -> ComplexNumber:
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
	
	if relevant_value * signi(relevant_value) < magnitude:
		return null
	
	match lock_type:
		lock_types.normal:
			new_key_count.set(relevant_value_sn, -signed_magnitude)
		lock_types.blast:
			new_key_count.set(relevant_value_sn, -relevant_value)
	
	return new_key_count

const flip_sign_dict := {
	Enums.sign.positive: Enums.sign.negative,
	Enums.sign.negative: Enums.sign.positive,
}
func flip_sign() -> LockData:
	sign = flip_sign_dict[sign]
	return self

const rotor_dict_value = {
	Enums.value.real: Enums.value.imaginary,
	Enums.value.imaginary: Enums.value.real,
}
func rotor() -> LockData:
	value_type = rotor_dict_value[value_type]
	if value_type == Enums.value.real:
		flip_sign()
	return self
