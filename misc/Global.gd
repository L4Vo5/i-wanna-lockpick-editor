@tool
extends Node


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

func _ready() -> void:
	if in_editor:
		key_pad.hide()

func _process(delta: float) -> void:
	time += delta

func _physics_process(delta: float) -> void:
	physics_time += delta
	physics_step += 1
	RenderingServer.global_shader_parameter_set(&"FPS_TIME", physics_time)
