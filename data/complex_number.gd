extends Resource
class_name ComplexNumber
@export var real_part := 0
@export var imaginary_part := 0

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

func is_zero() -> bool:
	return real_part == 0 and imaginary_part == 0
