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

static func new_with(r: int, i: int) -> ComplexNumber:
	var c := ComplexNumber.new()
	c._real_part = r
	c._imaginary_part = i
	return c

func duplicated() -> ComplexNumber:
	var c := ComplexNumber.new()
	c._real_part = real_part
	c._imaginary_part = imaginary_part
	return c

func set_real_part(val: int) -> void:
	if _real_part == val: return
	_real_part = val
	changed.emit()

func set_to(r: int, i: int) -> ComplexNumber:
	_real_part = r
	_imaginary_part = i
	changed.emit()
	return self

func set_to_this(other: ComplexNumber) -> ComplexNumber:
	_real_part = other.real_part
	_imaginary_part = other.imaginary_part
	changed.emit()
	return self 

func flip() -> ComplexNumber:
	_real_part *= -1
	_imaginary_part *= -1
	changed.emit()
	return self

func rotor() -> ComplexNumber:
	var new_imaginary := _real_part
	var new_real := -_imaginary_part
	_real_part = new_real
	_imaginary_part = new_imaginary
	changed.emit()
	return self

func add(other: ComplexNumber) -> ComplexNumber:
	if _real_part != Enums.INT_MAX:
		_real_part += other._real_part
	if _imaginary_part != Enums.INT_MIN:
		_imaginary_part += other._imaginary_part
	changed.emit()
	return self

func sub(other: ComplexNumber) -> ComplexNumber:
	if _real_part != Enums.INT_MAX:
		_real_part -= other._real_part
	if _imaginary_part != Enums.INT_MIN:
		_imaginary_part -= other._imaginary_part
	changed.emit()
	return self

func is_equal_to(other: ComplexNumber) -> bool:
	return _real_part == other._real_part and _imaginary_part == other._imaginary_part

func is_bigger_than(other: ComplexNumber) -> bool:
	return as_vec2().length() > other.as_vec2().length()

func as_vec2() -> Vector2i:
	return Vector2i(real_part, imaginary_part)

func has_value(r: int, i: int) -> bool:
	return _real_part == r and _imaginary_part == i

func is_zero() -> bool:
	return _real_part == 0 and _imaginary_part == 0

## will return true if it's in the fully negative quadrant, not including zero, but including -1+0i and 0-1i
func is_negative() -> bool:
	return (_real_part <= 0 and _imaginary_part <= 0) and (_real_part < 0 or _imaginary_part < 0)

# returns the sign in Enums.sign terms, assuming it's a 1d vector in either direction
func sign_1d() -> Enums.sign:
	assert(_real_part == 0 or _imaginary_part == 0)
	var val := _real_part + _imaginary_part
	if val >= 0:
		return Enums.sign.positive
	else:
		return Enums.sign.negative

# returns the value type in Enums.value terms, assuming it's a 1d vector in either direction
func value_type_1d() -> Enums.value:
	assert(_real_part == 0 or _imaginary_part == 0)
	if _imaginary_part != 0:
		return Enums.value.imaginary
	else:
		return Enums.value.real

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
