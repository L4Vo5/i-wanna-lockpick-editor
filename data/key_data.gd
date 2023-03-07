@tool
extends Resource
class_name KeyData

@export var amount := ComplexNumber.new_with(1, 0):
	set(val):
		if amount == val: return
		if is_instance_valid(amount):
			amount.changed.disconnect(emit_changed)
		amount = val
		if is_instance_valid(amount):
			amount.changed.connect(emit_changed)
		emit_changed()

## if the key is spent, in each universe
var _spent: Array[bool] = [false]
@export var type := key_types.add:
	set(val):
		if type == val: return
		type = val
		emit_changed()
@export var color := Enums.color.white:
	set(val):
		if color == val: return
		color = val
		emit_changed()

func is_spent() -> bool:
	return _spent[0]

func set_spent(val: bool) -> void:
	if _spent[0] == val: return
	_spent[0] = val
	emit_changed()

enum key_types {
	add, exact,
	star, unstar,
	flip, rotor, rotor_flip
}

func _init() -> void:
	if is_instance_valid(amount):
		amount.changed.connect(emit_changed)
