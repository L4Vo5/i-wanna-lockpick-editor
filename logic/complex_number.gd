extends Resource
class_name ComplexNumber
@export var real_part := 0
@export var imaginary_part := 0

static func new_with(real_part: int, imaginary_part: int) -> ComplexNumber:
	var kc := ComplexNumber.new()
	kc.real_part = real_part
	kc.imaginary_part = imaginary_part
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

