extends Node2D
class_name NodeDragger

@export var input_action := &"drag_camera"
@export var node: Node
@export var enabled := true:
	set(val):
		enabled = val
		if not enabled:
			action_is_pressed = 0
		set_process_input(enabled)
## This should be true when moving a camera.
@export var move_opposite_to_mouse := false

var action_is_pressed := 0
var last_mouse_pos := Vector2i.ZERO

func _ready() -> void:
	assert(node)
	assert(node is Node2D or node is Control)
	enabled = enabled # call setter

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(input_action):
		last_mouse_pos = DisplayServer.mouse_get_position()
		get_viewport().set_input_as_handled()
		action_is_pressed += 1
	elif event.is_action_released(input_action):
		action_is_pressed -= 1
		if action_is_pressed < 0:
			action_is_pressed = 0
	if event is InputEventMouseMotion:
		if action_is_pressed > 0:
			var new_mouse_pos := DisplayServer.mouse_get_position()
			var diff := new_mouse_pos - last_mouse_pos
			if move_opposite_to_mouse:
				diff = -diff
			last_mouse_pos = new_mouse_pos
			node.position += Vector2(diff)
			get_viewport().set_input_as_handled()
