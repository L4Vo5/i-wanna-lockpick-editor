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

## if the key is spent while playing the level
var is_spent := false:
	set(val):
		if is_spent == val: return
		is_spent = val
		emit_changed()

@export var type := Enums.key_types.add:
	set(val):
		if type == val: return
		type = val
		emit_changed()
@export var color := Enums.colors.white:
	set(val):
		if color == val: return
		color = val
		emit_changed()
@export var position := Vector2i(0, 0):
	set(val):
		if position == val: return
		position = val
		emit_changed()



func _init() -> void:
	if is_instance_valid(amount):
		amount.changed.connect(emit_changed)

func duplicated() -> KeyData:
	return duplicate(true)
