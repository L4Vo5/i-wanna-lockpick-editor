extends Node2D
class_name Level

@export var mimic_color := Enums.color.mimic
@export var key_counts := {
	Enums.color.mimic: ComplexNumber.new(),
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

# undo/redo actions should be handled somewhere in here, too

@export var player: Kid
var imaginary_view := false

func _ready() -> void:
	Global.current_level = self
