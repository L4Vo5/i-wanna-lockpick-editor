@tool
extends MarginContainer
class_name CounterPartEditor

signal delete
@export var lock_data: CounterPartData:
	set(val):
		if lock_data == val: return
		lock_data = val
		if not is_node_ready(): await ready
		_set_to_lock_data()
@onready var color_choice: ColorChoiceEditor = %ColorChoice
@onready var lock_n: Label = %LockN
@onready var delete_button: Button = %Delete
@export var lock_number := 1:
	set(val):
		if not is_node_ready(): await ready
		lock_number = val
		lock_n.text = "Counter %d" % lock_number
		lock_data.position = lock_number - 1

var editor_data: EditorData

func _ready() -> void:
	delete_button.pressed.connect(func(): delete.emit())
	
	color_choice.changed_color.connect(_update_lock_color)
	
	lock_n.text = "Counter %d" % lock_number
	lock_data.position = 0
	
	_set_to_lock_data()

# See _setting_to_data in DoorEditor
var _setting_to_data := false
# Sets the different controls to the lockdata's data
func _set_to_lock_data() -> void:
	_setting_to_data = true
	color_choice.set_to_color(lock_data.color)
	_setting_to_data = false

func _update_lock_color(color: Enums.Colors) -> void:
	if _setting_to_data: return
	lock_data.color = color_choice.color
	lock_data.emit_changed()
