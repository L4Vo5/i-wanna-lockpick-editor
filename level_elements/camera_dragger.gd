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
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			middle_is_pressed = event.is_pressed()
			last_mouse_pos = DisplayServer.mouse_get_position()
	if event is InputEventMouseMotion:
		if middle_is_pressed:
			camera.position_smoothing_enabled = false
			var new_mouse_pos := DisplayServer.mouse_get_position()
			var diff := last_mouse_pos - new_mouse_pos
			last_mouse_pos = new_mouse_pos
			camera.position += Vector2(diff)
			#get_parent().limit_camera()
