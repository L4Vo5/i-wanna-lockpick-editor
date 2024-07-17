@tool
extends Control
class_name NodeDragger

@export var input_action := &"drag_camera"
@export var node: Node:
	set = _set_node
## This should be true when moving a camera.
@export var move_opposite_to_mouse := false

signal moved_node

var action_is_pressed := false
var last_mouse_pos := Vector2i.ZERO

func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()

func _on_visibility_changed() -> void:
	if not visible:
		action_is_pressed = 0
	set_process_input(visible)

func _set_node(val: Node) -> void:
	if node == val: return
	node = val
	if node:
		assert(node is Node2D or node is Control)
	action_is_pressed = false

func _gui_input(event: InputEvent) -> void:
	if not node: return
	if event.is_action_pressed(input_action):
		last_mouse_pos = DisplayServer.mouse_get_position()
		action_is_pressed = true
		accept_event()
	elif event.is_action_released(input_action):
		action_is_pressed = Input.is_action_pressed(input_action)
		accept_event()

# unlike gui input, this should work even if the mouse is outside
func _input(event: InputEvent) -> void:
	assert(visible)
	if event is InputEventMouseMotion:
		if action_is_pressed:
			var new_mouse_pos := DisplayServer.mouse_get_position()
			var diff := new_mouse_pos - last_mouse_pos
			if move_opposite_to_mouse:
				diff = -diff
			last_mouse_pos = new_mouse_pos
			node.position += Vector2(diff)
			moved_node.emit()
			get_viewport().set_input_as_handled()
