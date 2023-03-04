@tool
extends Node

signal changed_level

var in_editor := Engine.is_editor_hint()
var print_actions := true
@onready var key_pad: Control = %KeyPad

var current_level: Level:
	set(val):
		if current_level == val: return
		current_level = val
		changed_level.emit()

var time := 0.0

func _ready() -> void:
	if in_editor:
		key_pad.hide()

func _process(delta: float) -> void:
	time += delta
