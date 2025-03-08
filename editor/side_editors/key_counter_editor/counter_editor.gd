@tool
extends Control
class_name CounterEditor

@onready var counter: KeyCounter = %KeyCounter
@export var data: CounterData:
	set(val):
		data = val
		if not is_node_ready(): await ready
		counter.data = data
		_set_to_counter_data()

@onready var length: SpinBox = %Width
@onready var add_counter: Button = %AddCounter
@onready var counter_part_editor_parent: BoxContainer = %CounterPartEditors

const counter_part_editor := preload("res://editor/side_editors/key_counter_editor/counter_part_editor.tscn")
var editor_data: EditorData

func _init() -> void:
	data = CounterData.new()
	data.length = 200
	var base_color := CounterPartData.new()
	base_color.color = Enums.Colors.White
	data.add_counter(base_color)

func _ready() -> void:
	counter.data = data
	var line_edit = length.get_line_edit()
	line_edit.add_theme_constant_override(&"minimum_character_width", 2)
	line_edit.expand_to_text_length = true
	
	length.tooltip_text = "Width of the key counter in pixels."
	length.value_changed.connect(_update_counter_width.unbind(1))
	add_counter.pressed.connect(_add_new_counter_part)

# This avoids signals changing the counter data while it's being set here
var _setting_to_data := false
func _set_to_counter_data() -> void:
	_setting_to_data = true
	length.value = data.get_rect().size.x
	
	_regen_counter_part_editors()
	_setting_to_data = false

func _update_counter_width() -> void:
	if _setting_to_data: return
	data.length = length.value
	data.emit_changed()

func _regen_counter_part_editors() -> void:
	for child in counter_part_editor_parent.get_children():
		child.queue_free()
	for counter_part_data in data.colors:
		var counter_part_editor: CounterPartEditor = counter_part_editor.instantiate()
		counter_part_editor.counter_part_data = counter_part_data
		counter_part_editor.delete.connect(_delete_counter_part_editor.bind(counter_part_editor))
		counter_part_editor_parent.add_child(counter_part_editor)

func _add_new_counter_part() -> void:
	var new_counter_part := CounterPartData.new()
	new_counter_part.color = Enums.Colors.Stone
	data.add_counter(new_counter_part)
	
	var counter_part_editor: CounterPartEditor = counter_part_editor.instantiate()
	counter_part_editor.editor_data = editor_data
	var i := counter_part_editor_parent.get_child_count() + 1
	counter_part_editor.counter_part_number = i
	counter_part_editor.counter_part_data = new_counter_part
	counter_part_editor.delete.connect(_delete_counter_part_editor.bind(counter_part_editor))
	counter_part_editor_parent.add_child(counter_part_editor)
	
	add_counter.text = "Add another Counter"

func _delete_counter_part_editor(which: CounterPartEditor) -> void:
	var i := which.counter_part_number - 1
	data.remove_color_at(i)
	var counter_part_editors := counter_part_editor_parent.get_children()
	counter_part_editors[i].queue_free()
	for j in range(i+1, counter_part_editors.size()):
		counter_part_editors[j].counter_part_number = j
