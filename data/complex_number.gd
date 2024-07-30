@tool
extends Resource
class_name ComplexNumber

# grr it's so hard to emit changed when values are changed while also being able to change both at once without it emitting changed in between... one of the worst godot 4 changes 
@export var real_part := 0:
	set(val):
		if _real_part == val: return
		_real_part = val
		changed.emit()
	get:
		return _real_part
@export var imaginary_part := 0:
	set(val):
		if _imaginary_part == val: return
		_imaginary_part = val
		changed.emit()
	get:
		return _imaginary_part
# Enums.INT_MAX and INT_MIN represent positive and negative infinity for amounts
# TODO: 1_000_000_000_000_000_000 (1 trillion/quintillion) shall be the typical limit for most intents and purposes
var _real_part := 0
var _imaginary_part := 0

## Makes a new complex number with the given real and imaginary components
static func new_with(r: int, i: int) -> ComplexNumber:
	var c := ComplexNumber.new()
	c._real_part = r
	c._imaginary_part = i
	return c

## Duplicates the complex number (faster than the default .duplicate())
func duplicated() -> ComplexNumber:
	var c := ComplexNumber.new()
	c._real_part = real_part
	c._imaginary_part = imaginary_part
	return c

## Changes the real and imaginary components to the given value. Also returns itself for chaining purposes.
func set_to(r: int, i: int) -> ComplexNumber:
	_real_part = r
	_imaginary_part = i
	changed.emit()
	return self

## Changes the real and imaginary components to match another complex number. Also returns itself for chaining purposes.
func set_to_this(other: ComplexNumber) -> ComplexNumber:
	_real_part = other.real_part
	_imaginary_part = other.imaginary_part
	changed.emit()
	return self 

## Flips the complex number. Also returns itself for chaining purposes.
func flip() -> ComplexNumber:
	_real_part *= -1
	_imaginary_part *= -1
	changed.emit()
	return self

## Returns a new complex number that is equivalent to this one but flipped. The current ComplexNumber is unchanged.
func flipped() -> ComplexNumber:
	return new_with(_real_part * -1, _imaginary_part * -1)

## Rotates the complex number 90° ccw (multiplies by i). Also returns itself for chaining purposes.
func rotor() -> ComplexNumber:
	var new_imaginary := _real_part
	var new_real := -_imaginary_part
	_real_part = new_real
	_imaginary_part = new_imaginary
	changed.emit()
	return self

## Adds the value of another complex number. Also returns itself for chaining purposes.
func add(other: ComplexNumber) -> ComplexNumber:
	if _real_part != Enums.INT_MAX and _real_part != Enums.INT_MIN:
		_real_part += other._real_part
	if _imaginary_part != Enums.INT_MAX and _imaginary_part != Enums.INT_MIN:
		_imaginary_part += other._imaginary_part
	changed.emit()
	return self

## Subtracts the value of another complex number. Also returns itself for chaining purposes.
func sub(other: ComplexNumber) -> ComplexNumber:
	return add(other.flipped())

## Returns true if both complex numbers have the same value
func is_equal_to(other: ComplexNumber) -> bool:
	return _real_part == other._real_part and _imaginary_part == other._imaginary_part

## Returns true if the value of the complex number is exactly (r, i)
func has_value(r: int, i: int) -> bool:
	return _real_part == r and _imaginary_part == i

## Returns true if the value of the complex number is exactly 0
func is_zero() -> bool:
	return _real_part == 0 and _imaginary_part == 0

## Returns true if the number is in the fully negative quadrant, not including zero, but including -1+0i, 0-1i, etc.
func is_negative() -> bool:
	return (_real_part <= 0 and _imaginary_part <= 0) and (_real_part < 0 or _imaginary_part < 0)

## Returns the sign in Enums.Sign terms, assuming it's a 1d vector in either direction
func sign_1d() -> Enums.Sign:
	assert(_real_part == 0 or _imaginary_part == 0)
	var val := _real_part + _imaginary_part
	if val >= 0:
		return Enums.Sign.Positive
	else:
		return Enums.Sign.Negative

## Returns the value type in Enums.Value terms, assuming it's a 1d vector in either direction
func value_type_1d() -> Enums.Value:
	assert(_real_part == 0 or _imaginary_part == 0)
	if _imaginary_part != 0:
		return Enums.Value.Imaginary
	else:
		return Enums.Value.Real

func _to_string() -> String:
	var s := ""
	
	var s_real := str(_real_part)
	var s_img := str(_imaginary_part)
	if _real_part == Enums.INT_MAX:
		s_real = "∞"
	if _real_part == Enums.INT_MIN:
		s_real = "-∞"
	if _imaginary_part == Enums.INT_MAX:
		s_img = "∞"
	if _imaginary_part == Enums.INT_MIN:
		s_img = "-∞"
	
	# simple case if no imaginary part
	if _imaginary_part == 0:
		s += s_real
	# there's imaginary part
	else:
		# don't include real part if 0
		if _real_part != 0:
			s += s_real
			# draw a + if imaginary is positive (only if there's reals)
			if _imaginary_part > 0:
				s += "+"
		s += s_img
		s += "i"
	return s
