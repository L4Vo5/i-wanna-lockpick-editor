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

@export var is_infinite := false:
	set(val):
		if is_infinite == val: return
		is_infinite = val
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
var glitch_color := Enums.colors.glitch


func _init() -> void:
	amount.changed.connect(emit_changed)

# TODO: Optimize if needed
func duplicated() -> KeyData:
	return duplicate(true)

func get_rect() -> Rect2i:
	return Rect2i(position, Vector2i(32, 32))

func get_used_color() -> Enums.colors:
	if color == Enums.colors.glitch:
		return glitch_color
	else:
		return color

# Called by the actual in-level Key
func update_glitch_color(new_glitch_color: Enums.colors) -> void:
	glitch_color = new_glitch_color

func get_mouseover_text() -> String:
	var s := ""
	if is_infinite:
		s += "Infinite "
	s += Enums.COLOR_NAMES[color].capitalize() + " "
	if type != Enums.key_types.add:
		s += Enums.KEY_TYPE_NAMES[type].capitalize() + " "
	s += "Key"
	if type == Enums.key_types.add or type == Enums.key_types.exact:
		if not amount.has_value(1, 0):
			s += "\n"
			s += "Amount: " + str(amount)
	if color == Enums.colors.glitch:
		s += "\nMimic: " + Enums.COLOR_NAMES[glitch_color].capitalize()
	return s
