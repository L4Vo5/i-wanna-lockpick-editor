@tool
extends Resource
class_name KeyData

static var level_element_type := Enums.LevelElementTypes.Key

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

@export var type := Enums.KeyTypes.Add:
	set(val):
		if type == val: return
		type = val
		emit_changed()
@export var color := Enums.Colors.White:
	set(val):
		if color == val: return
		color = val
		emit_changed()
@export var position := Vector2i(0, 0):
	set(val):
		if position == val: return
		position = val
		emit_changed()
var glitch_color := Enums.Colors.Glitch


func _init() -> void:
	amount.changed.connect(emit_changed)

# TODO: Optimize if needed
func duplicated() -> KeyData:
	return duplicate(true)

func get_rect() -> Rect2i:
	return Rect2i(position, Vector2i(32, 32))

func get_used_color() -> Enums.Colors:
	if color == Enums.Colors.Glitch:
		return glitch_color
	else:
		return color

# Called by the actual in-level KeyElement
func update_glitch_color(new_glitch_color: Enums.Colors) -> void:
	glitch_color = new_glitch_color

func get_mouseover_text() -> String:
	var s := ""
	if is_infinite:
		s += "Infinite "
	s += Enums.Colors.find_key(color) + " "
	if type != Enums.KeyTypes.Add:
		s += Enums.KeyTypes.find_key(type) + " "
	s += "Key"
	if type == Enums.KeyTypes.Add or type == Enums.KeyTypes.Exact:
		if not amount.has_value(1, 0):
			s += "\n"
			s += "Amount: " + str(amount)
	if color == Enums.Colors.Glitch:
		s += "\nMimic: " + Enums.Colors.find_key(glitch_color)
	return s
