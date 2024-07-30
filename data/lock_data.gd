@tool
extends Resource
class_name LockData

@export var color := Enums.Colors.None

@export var magnitude := 1

@export var sign := Enums.Sign.Positive

@export var value_type := Enums.Value.Real

@export var lock_type := Enums.LockTypes.Normal

# visual settings

## displayed size
@export var size := Vector2i(18, 18):
	set(val):
		if size == val: return
		size = val
		changed.emit()

## minimum size the lock could have (mainly useful for the editor)
var minimum_size := Vector2i(0, 0)

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
var glitch_color := Enums.Colors.Glitch:
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

func get_used_color() -> Enums.Colors:
	var used_color := color
	if is_cursed:
		used_color = Enums.Colors.Brown
	elif used_color == Enums.Colors.Glitch:
		used_color = glitch_color
	return used_color

## no-nonsense returns the lockdata's amount as a complex number
func get_complex_amount() -> ComplexNumber:
	assert(PerfManager.start("LockData::get_complex_amount()"))
	var val := magnitude
	if sign == Enums.Sign.Negative: val *= -1
	var num := ComplexNumber.new()
	if value_type == Enums.Value.Real:
		num.real_part = val
	else:
		num.imaginary_part = val
	assert(PerfManager.end("LockData::get_complex_amount()"))
	return num

## returns the sign after applying the current rotation
func get_sign_rot() -> Enums.Sign:
	if rotation == 0 or (rotation == 90 and value_type == Enums.Value.Real) or (rotation == 270 and value_type == Enums.Value.Imaginary):
		return sign
	else:
		return 1 - sign

## returns the value type after applying the current rotation
func get_value_rot() -> Enums.Value:
	if rotation == 0 or rotation == 180:
		return value_type
	else:
		return 1 - value_type

const flip_sign_dict := {
	Enums.Sign.Positive: Enums.Sign.Negative,
	Enums.Sign.Negative: Enums.Sign.Positive,
}
## should be useful for the editor
func flip_sign() -> LockData:
	sign = flip_sign_dict[sign]
	return self

const rotor_dict_value = {
	Enums.Value.Real: Enums.Value.Imaginary,
	Enums.Value.Imaginary: Enums.Value.Real,
}
## should be useful for the editor
func rotor() -> LockData:
	value_type = rotor_dict_value[value_type]
	if value_type == Enums.Value.Real:
		flip_sign()
	return self

# Minimum size depends on:
# value, rotation, magnitude, lock_arrangement
@warning_ignore("shadowed_variable")
func update_minimum_size() -> void:
	assert(PerfManager.start(&"LockData::update_minimum_size"))
	var value_type := get_value_rot()
	
	var min_size: Vector2i
	var using_arrangement := false
	match lock_type:
		Enums.LockTypes.Blast:
			var s := "x" if value_type == Enums.Value.Real else "+"
			min_size = LockCountDraw.get_min_size(s, 2)
		Enums.LockTypes.All:
			min_size = LockCountDraw.get_min_size("=", 2)
		Enums.LockTypes.Blank:
			min_size = Vector2i(1, 1)
		Enums.LockTypes.Normal:
			# TODO: When supporting custom arrangements, level_data will have to be passed here..
			var arrangement = Rendering.get_lock_arrangement(null, magnitude, lock_arrangement)
			if arrangement != null:
				min_size = arrangement[0]
				using_arrangement = true
			else:
				var s := str(magnitude)
				var type := 2 if dont_show_lock else 0 if value_type == Enums.Value.Real else 1 if value_type == Enums.Value.Imaginary else 2
				min_size = LockCountDraw.get_min_size(s, type)
	
	if not using_arrangement:
		min_size += Vector2i(4, 4) # account for the frame size
	minimum_size = min_size
	size = size.clamp(minimum_size, size)
	assert(PerfManager.end(&"LockData::update_minimum_size"))

func check_valid(level_data: LevelData, should_correct: bool) -> bool:
	var is_valid := true
	if color == Enums.Colors.None:
		level_data.add_invalid_reason("Lock has none color", false)
		is_valid = false
	if magnitude == 0 and lock_type == Enums.LockTypes.Normal:
		level_data.add_invalid_reason("Lock has normal type but magnitude 0", true)
		is_valid = is_valid and should_correct
		if should_correct:
			magnitude = 1
	return is_valid
