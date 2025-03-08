@tool
extends MarginContainer
class_name CounterPartEditor

signal delete
@export var counter_part_data: CounterPartData:
	set(val):
		if counter_part_data == val: return
		counter_part_data = val
		if not is_node_ready(): await ready
		_set_to_counter_part_data()
@onready var color_choice: ColorChoiceEditor = %ColorChoice
@onready var counter_part_n: Label = %CounterN
@onready var delete_button: Button = %Delete
@export var counter_part_number := 1:
	set(val):
		if not is_node_ready(): await ready
		counter_part_number = val
		counter_part_n.text = "Counter %d" % counter_part_number
		counter_part_data.position = counter_part_number - 1

var editor_data: EditorData

func _ready() -> void:
	delete_button.pressed.connect(func(): delete.emit())
	
	color_choice.changed_color.connect(_update_counter_part_color)
	
	counter_part_n.text = "Counter %d" % counter_part_number
	counter_part_data.position = 0
	
	_set_to_counter_part_data()

# See _setting_to_data in DoorEditor
var _setting_to_data := false
# Sets the different controls to the counter_part_data's data
func _set_to_counter_part_data() -> void:
	_setting_to_data = true
	color_choice.set_to_color(counter_part_data.color)
	_setting_to_data = false

func _update_counter_part_color(color: Enums.Colors) -> void:
	if _setting_to_data: return
	counter_part_data.color = color_choice.color
	counter_part_data.emit_changed()
