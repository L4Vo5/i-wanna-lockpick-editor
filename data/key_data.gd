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

## if the key is spent
var is_spent := false:
	set(val):
		if is_spent == val: return
		is_spent = val
		changed.emit()

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


enum key_types {
	add, exact,
	star, unstar,
	flip, rotor, rotor_flip
}

func _init() -> void:
	if is_instance_valid(amount):
		amount.changed.connect(emit_changed)
