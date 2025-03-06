@tool
extends Control
class_name CounterEditor

@onready var counter: KeyCounter = %KeyCounter
@export var data: CounterData:
	set(val):
		data = val
		if not is_node_ready(): await ready
		counter.data = data
		_set_to_door_data()

@onready var length: SpinBox = %Width
@onready var add_counter: Button = %AddLock
@onready var counter_part_editor_parent: BoxContainer = %LockEditors

const LOCK_EDITOR := preload("res://editor/side_editors/key_counter_editor/counter_part_editor.tscn")
var editor_data: EditorData

func _init() -> void:
	data = CounterData.new()
	data.length = 200
	var lock := CounterPartData.new()
	lock.color = Enums.Colors.Stone
	data.add_counter(lock)

func _ready() -> void:
	counter.data = data
	var line_edit = length.get_line_edit()
	line_edit.add_theme_constant_override(&"minimum_character_width", 2)
	line_edit.expand_to_text_length = true
	
	length.tooltip_text = "However long the key counter will be. 32 is 1 tile."
	length.value_changed.connect(_update_door_size.unbind(1))
	add_counter.pressed.connect(_add_new_lock)

# This avoids signals changing the door data while it's being set here
# Fixes, for example, doors with sizes of 64x64 changing the width to 64, which calls _update_door_size, which sets the height to the default of 32
var _setting_to_data := false
func _set_to_door_data() -> void:
	_setting_to_data = true
	length.value = data.get_rect().size.x
	
	_regen_lock_editors()
	_setting_to_data = false

# Setting DoorData to the editor's values

func _update_door_size() -> void:
	if _setting_to_data: return
	data.length = length.value
	data.emit_changed()

func _regen_lock_editors() -> void:
	for child in counter_part_editor_parent.get_children():
		child.queue_free()
	var i := 1
	for lock_data in data.colors:
		var lock_editor: CounterPartEditor = LOCK_EDITOR.instantiate()
		lock_editor.lock_data = lock_data
		lock_editor.delete.connect(_delete_lock.bind(lock_editor))
		counter_part_editor_parent.add_child(lock_editor)

func _add_new_lock() -> void:
	var new_lock := CounterPartData.new()
	new_lock.color = Enums.Colors.Stone
	data.add_counter(new_lock)
	
	var lock_editor: CounterPartEditor = LOCK_EDITOR.instantiate()
	lock_editor.editor_data = editor_data
	var i := counter_part_editor_parent.get_child_count() + 1
	lock_editor.lock_number = i
	lock_editor.lock_data = new_lock
	lock_editor.delete.connect(_delete_lock.bind(lock_editor))
	counter_part_editor_parent.add_child(lock_editor)
	
	add_counter.text = "Add another Counter"

func _delete_lock(which: CounterPartEditor) -> void:
	var i := which.lock_number - 1
	data.remove_lock_at(i)
	var lock_editors := counter_part_editor_parent.get_children()
	lock_editors[i].queue_free()
	for j in range(i+1, lock_editors.size()):
		lock_editors[j].lock_number = j
