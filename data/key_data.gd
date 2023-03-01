extends Resource
class_name KeyData

@export var amount := 1
## if the key is spent, in every universe
@export var spent := [false]
@export var type := key_types.real
@export var color := Enums.color.white

enum key_types {
	real, imaginary, flip, rotor, rotor_flip
}
