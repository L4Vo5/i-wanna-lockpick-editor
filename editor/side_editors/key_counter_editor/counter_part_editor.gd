@tool
extends MarginContainer
class_name CounterPartEditor

signal delete
@export var counter_part_data: CounterPartData:
	set(val):
		if counter_part_data == val: return
		counter_part_data = val
		if not is_node_ready(): return
		_set_to_counter_part_data()
@onready var color_choice: ColorChoiceEditor = %ColorChoice
@onready var counter_part_n: Label = %CounterN
@onready var delete_button: Button = %Delete

func _ready() -> void:
	delete_button.pressed.connect(func(): delete.emit())
	color_choice.changed_color.connect(_update_counter_part_color)
	get_parent().child_order_changed.connect(_update_number_text)
	_update_number_text()
	
	_set_to_counter_part_data()

func _update_number_text() -> void:
	counter_part_n.text = "Counter %d" %  (get_index()+1)

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
