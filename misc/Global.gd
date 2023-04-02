@tool
extends Node

# in the godot editor, as opposed to the level editor
var in_editor := Engine.is_editor_hint()
var in_level_editor := false
@onready var key_pad: Control = %KeyPad

signal changed_level
var current_level: Level:
	set(val):
		if current_level == val: return
		current_level = val
		changed_level.emit()

var time := 0.0
var physics_time := 0.0
var physics_step := 0
var _current_mode := Modes.GAMEPLAY

enum Modes {
	GAMEPLAY, EDITOR
}

func _ready() -> void:
	if in_editor:
		key_pad.hide()
	set_mode(_current_mode)

func _process(delta: float) -> void:
	time += delta

func _physics_process(delta: float) -> void:
	physics_time += delta
	physics_step += 1
	RenderingServer.global_shader_parameter_set(&"FPS_TIME", physics_time)

# sets the viewport according to gameplay settings
func _set_viewport_to_gameplay() -> void:
	if in_editor: return
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS

# sets the viewport according to editor settings
func _set_viewport_to_editor() -> void:
	if in_editor: return
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().root.mode = Window.MODE_MAXIMIZED

func set_mode(mode: Modes) -> void:
	if _current_mode == mode: return
	_current_mode = mode 
	if _current_mode == Modes.GAMEPLAY:
		_set_viewport_to_gameplay()
	else:
		_set_viewport_to_editor()
