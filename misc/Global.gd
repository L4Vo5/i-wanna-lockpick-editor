@tool
extends Node

# Engine.is_editor_hint() to know if you're in the editor
signal changed_level

var print_actions := true

var current_level: Level:
	set(val):
		if current_level == val: return
		current_level = val
		changed_level.emit()

var time := 0.0

func _process(delta: float) -> void:
	time += delta
