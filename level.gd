extends Node2D
class_name Level

signal changed_glitch_color
@export var glitch_color := Enums.color.pure
@export var key_counts := {
	Enums.color.glitch: ComplexNumber.new(),
	Enums.color.black: ComplexNumber.new(),
	Enums.color.white: ComplexNumber.new(),
	Enums.color.pink: ComplexNumber.new(),
	Enums.color.orange: ComplexNumber.new(),
	Enums.color.purple: ComplexNumber.new(),
	Enums.color.cyan: ComplexNumber.new(),
	Enums.color.red: ComplexNumber.new(),
	Enums.color.green: ComplexNumber.new(),
	Enums.color.blue: ComplexNumber.new(),
	Enums.color.brown: ComplexNumber.new(),
	Enums.color.pure: ComplexNumber.new(),
	Enums.color.master: ComplexNumber.new(),
	Enums.color.stone: ComplexNumber.new(),
}
@export var star_keys := {
	Enums.color.glitch: false,
	Enums.color.black: false,
	Enums.color.white: false,
	Enums.color.pink: false,
	Enums.color.orange: false,
	Enums.color.purple: false,
	Enums.color.cyan: false,
	Enums.color.red: false,
	Enums.color.green: false,
	Enums.color.blue: false,
	Enums.color.brown: false,
	Enums.color.pure: false,
	Enums.color.master: false,
	Enums.color.stone: false,
}

# undo/redo actions should be handled somewhere in here, too

@export var player: Kid
signal changed_i_view
var i_view := false

var time := 0.0
func _process(delta: float) -> void:
	return
	time += delta
	if time >= 0.4:
		time -= 0.4
	else:
		return
	for key in star_keys.keys():
		star_keys[key] = true if randi() % 2 == 0 else false
	for count in key_counts.values():
		var get_val = func():
			var value = randf_range(-100, 100)
			for i in 5:
				value *= randf()
			return int(value)
		count.real_part = get_val.call()
		count.imaginary_part = get_val.call()

func _input(event: InputEvent) -> void:
	if event.is_action(&"i-view") and event.is_pressed():
		i_view = not i_view
		changed_i_view.emit()

func _ready() -> void:
	Global.current_level = self

func set_glitch_color(color: Enums.color):
	if glitch_color == color: return
	glitch_color = color
	changed_glitch_color.emit()
