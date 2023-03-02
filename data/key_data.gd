extends Resource
class_name KeyData

@export var amount := ComplexNumber.new_with(1, 0)
## if the key is spent, in every universe
@export var spent := [false]
@export var type := key_types.add
@export var color := Enums.color.white

enum key_types {
	add, exact,
	star, unstar,
	flip, rotor, rotor_flip
}
