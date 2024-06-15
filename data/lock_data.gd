@tool
extends Resource
class_name LockData

@export var color := Enums.colors.none:
	set(val):
		if color == val: return
		color = val
		changed.emit()

@export var magnitude := 1:
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

@export var lock_type := Enums.lock_types.normal:
	set(val):
		if lock_type == val: return
		lock_type = val
		changed.emit()

# visual settings

## displayed size
@export var size := Vector2i(18, 18):
	set(val):
		if size == val: return
		size = val
		changed.emit()

## minimum size (editor info. the editor itself should enforce this to be the actual minimum size)
## TODO: since it's editor-only, it doesn't emit changed(), to avoid redrawing locks xd bad fix ik
signal changed_minimum_size
var minimum_size := Vector2i(0, 0):
	set(val):
		if minimum_size == val: return
		minimum_size = val
		changed_minimum_size.emit()
#		changed.emit()

## position in door
@export var position := Vector2i(7, 7):
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
var glitch_color := Enums.colors.glitch:
	set(val):
		if glitch_color == val: return
		glitch_color = val
		changed.emit()

## When cursed, this is true to force the lock to be rendered brown.
var is_cursed := false:
	set(val):
		if is_cursed == val: return
		is_cursed = val
		changed.emit()

## used if the door's count doesn't align with the i-view status
var dont_show_frame := false:
	set(val):
		if dont_show_frame == val: return
		dont_show_frame = val
		changed.emit()

## separate thing to hide locks
var dont_show_locks := false:
	set(val):
		if dont_show_locks == val: return
		dont_show_locks = val
		changed.emit()

## rotation for rendering i-view and negative doors without destructively affecting the lock data
var rotation := 0:
	set(val):
		if rotation == val: return
		rotation = val
		changed.emit()

func duplicated() -> LockData:
	var lock := LockData.new()
	lock.color = color
	lock.magnitude = magnitude
	lock.sign = sign
	lock.value_type = value_type
	lock.lock_type = lock_type
	lock.size = size
	lock.position = position
	lock.lock_arrangement = lock_arrangement
	lock.dont_show_lock = dont_show_lock
	return lock

func get_used_color() -> Enums.colors:
	var used_color := color
	if is_cursed:
		used_color = Enums.colors.brown
	elif used_color == Enums.colors.glitch:
		used_color = glitch_color
	return used_color

## no-nonsense returns the lockdata's amount as a complex number
func get_complex_amount() -> ComplexNumber:
	assert(PerfManager.start("LockData::get_complex_amount()"))
	var val := magnitude
	if sign == Enums.sign.negative: val *= -1
	var num := ComplexNumber.new()
	if value_type == Enums.value.real:
		num.real_part = val
	else:
		num.imaginary_part = val
	assert(PerfManager.end("LockData::get_complex_amount()"))
	return num

## returns the sign after applying the current rotation
func get_sign_rot() -> Enums.sign:
	if rotation == 0 or (rotation == 90 and value_type == Enums.value.real) or (rotation == 270 and value_type == Enums.value.imaginary):
		return sign
	else:
		return 1 - sign

## returns the value type after applying the current rotation
func get_value_rot() -> Enums.value:
	if rotation == 0 or rotation == 180:
		return value_type
	else:
		return 1 - value_type

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

func check_valid(level_data: LevelData, should_correct: bool) -> bool:
	var is_valid := true
	if color == Enums.colors.none:
		level_data.add_invalid_reason("Lock has none color", false)
		is_valid = false
	if magnitude == 0 and lock_type == Enums.lock_types.normal:
		level_data.add_invalid_reason("Lock has normal type but magnitude 0", true)
		is_valid = is_valid and should_correct
		if should_correct:
			magnitude = 1
	return is_valid
