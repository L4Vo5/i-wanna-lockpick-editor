@tool
extends Node

# Engine.is_editor_hint() to know if you're in the editor

var print_actions := true

var current_level: Level

var time := 0.0

func _process(delta: float) -> void:
	time += delta
