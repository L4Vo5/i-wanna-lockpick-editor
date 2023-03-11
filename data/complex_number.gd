@tool
extends Resource
class_name ComplexNumber

@export var real_part := 0:
	set(val):
		if real_part == val: return
		real_part = val
		changed.emit()
@export var imaginary_part := 0:
	set(val):
		if imaginary_part == val: return
		imaginary_part = val
		changed.emit()

static func new_with(_real_part: int, _imaginary_part: int) -> ComplexNumber:
	var kc := ComplexNumber.new()
	kc.real_part = _real_part
	kc.imaginary_part = _imaginary_part
	return kc

func flip() -> ComplexNumber:
	real_part *= -1
	imaginary_part *= -1
	return self

func rotor() -> ComplexNumber:
	var new_imaginary := real_part
	var new_real := -imaginary_part
	real_part = new_real
	imaginary_part = new_imaginary
	return self

func add(other: ComplexNumber) -> ComplexNumber:
	real_part += other.real_part
	imaginary_part += other.imaginary_part
	return self

func is_equal_to(other: ComplexNumber) -> bool:
	return real_part == other.real_part and imaginary_part == other.imaginary_part

func is_zero() -> bool:
	return real_part == 0 and imaginary_part == 0

## will return true if it's in the fully negative quadrant, not including zero, but including -1+0i and 0-1i
func is_negative() -> bool:
	return (real_part <= 0 and imaginary_part <= 0) and (real_part < 0 or imaginary_part < 0)

func _to_string() -> String:
	var str := ""
	# simple case if no imaginary part
	if imaginary_part == 0:
		str += str(real_part)
	# there's imaginary part
	else:
		# don't include real part if 0
		if real_part != 0:
			str += str(real_part)
			# draw a + if imaginary is positive (only if there's reals)
			if imaginary_part > 0:
				str += "+"
		str += str(imaginary_part)
		str += "i"
	return str
