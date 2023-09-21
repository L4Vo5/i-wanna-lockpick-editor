extends Node2D
class_name CameraDragger

@export var camera: Camera2D
var enabled := false:
	set(val):
		enabled = val
		set_process_input(enabled)

var middle_is_pressed := false
var last_mouse_pos := Vector2i.ZERO

func _ready() -> void:
	assert(camera)
	enabled = enabled # call setter

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("drag_camera"):
		last_mouse_pos = DisplayServer.mouse_get_position()
		get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion:
		if Input.is_action_pressed("drag_camera"):
			camera.position_smoothing_enabled = false
			var new_mouse_pos := DisplayServer.mouse_get_position()
			var diff := last_mouse_pos - new_mouse_pos
			last_mouse_pos = new_mouse_pos
			camera.position += Vector2(diff)
			get_viewport().set_input_as_handled()
