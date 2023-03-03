extends Node2D
class_name Level

signal changed_glitch_color
@export var glitch_color := [Enums.color.pure]
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
var imaginary_view := false

func _ready() -> void:
	Global.current_level = self

func set_glitch_color(color: Enums.color):
	if glitch_color[0] == color: return
	glitch_color[0] = color
	changed_glitch_color.emit()
