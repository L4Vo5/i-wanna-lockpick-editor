@tool
extends Control
class_name DoorEditor

@export var door_data: DoorData:
	set(val):
		door_data = val.duplicated()
		if not is_node_ready(): await ready
		# TODO: Allow editing doors in the level (currently not done so you can't resize them)
		door.door_data = door_data
		_set_to_door_data()
@onready var door: Door = %Door

@onready var ice_checkbox: CheckBox = %IceCheckbox
@onready var erosion_checkbox: CheckBox = %ErosionCheckbox
@onready var paint_checkbox: CheckBox = %PaintCheckbox
@onready var ice_button: Button = %IceButton
@onready var erosion_button: Button = %ErosionButton
@onready var paint_button: Button = %PaintButton
@onready var width: SpinBox = %Width
@onready var height: SpinBox = %Height
@onready var real_copies: SpinBox = %RealCopies
@onready var imaginary_copies: SpinBox = %ImaginaryCopies
@onready var color_choice: ColorChoiceEditor = %ColorChoice
@onready var lock_editor_parent: VBoxContainer = %LockEditors
@onready var add_lock: Button = %AddLock
const LOCK_EDITOR := preload("res://editor/lock_editor.tscn")
## the idea is that non-standard-levels should be able to exist, maybe, but they must be labeled as such (for example doors with non-32-multiple sizes, or a door starting out browned or with a different glitch color. things that are valid but.. not standard)
## unimplemented for now tho lol
var non_standard_mode := false
var editor_data: EditorData

func _init() -> void:
	door_data = DoorData.new()
	door_data.outer_color = Enums.colors.white
	var lock := LockData.new()
	lock.color = Enums.colors.white
	# "Please don't push_back on these or anything!! use add_lock or remove_lock"
	#door_data.locks.push_back(lock)
	door_data.add_lock(lock)

func _ready() -> void:
	door.door_data = door_data
	width.get_line_edit().add_theme_constant_override(&"minimum_character_width", 2)
	height.get_line_edit().add_theme_constant_override(&"minimum_character_width", 2)
	real_copies.get_line_edit().add_theme_constant_override(&"minimum_character_width", 2)
	imaginary_copies.get_line_edit().add_theme_constant_override(&"minimum_character_width", 2)
	width.get_line_edit().expand_to_text_length = true
	height.get_line_edit().expand_to_text_length = true
	real_copies.get_line_edit().expand_to_text_length = true
	imaginary_copies.get_line_edit().expand_to_text_length = true
	
	
	ice_button.tooltip_text = "Ice curse, broken with 1 red key or more."
	erosion_button.tooltip_text = "Erosion curse, broken with 5 green keys or more."
	paint_button.tooltip_text = "Paint curse, broken with 3 blue keys or more."
	ice_button.toggled.connect(ice_checkbox.set_pressed_no_signal)
	ice_button.toggled.connect(set_curse.bind(Enums.curse.ice))
	erosion_button.toggled.connect(erosion_checkbox.set_pressed_no_signal)
	erosion_button.toggled.connect(set_curse.bind(Enums.curse.erosion))
	paint_button.toggled.connect(paint_checkbox.set_pressed_no_signal)
	paint_button.toggled.connect(set_curse.bind(Enums.curse.paint))
	
	width.value_changed.connect(_update_door_size.unbind(1))
	height.value_changed.connect(_update_door_size.unbind(1))
	real_copies.value_changed.connect(_update_door_amount.unbind(1))
	imaginary_copies.value_changed.connect(_update_door_amount.unbind(1))
	color_choice.changed_color.connect(_update_door_color)
	
	add_lock.pressed.connect(_add_new_lock)

# This avoids signals changing the door data while it's being set here
# Fixes, for example, doors with sizes of 64x64 changing the width to 64, which calls _update_door_size, which sets the height to the default of 32
var _setting_to_data := false
func _set_to_door_data() -> void:
	_setting_to_data = true
	ice_button.button_pressed = door_data.get_curse(Enums.curse.ice)
	erosion_button.button_pressed = door_data.get_curse(Enums.curse.erosion)
	paint_button.button_pressed = door_data.get_curse(Enums.curse.paint)
	width.value = door_data.size.x
	height.value = door_data.size.y
	
	real_copies.value = door_data.amount.real_part
	imaginary_copies.value = door_data.amount.imaginary_part
	
	color_choice.set_to_color(door_data.outer_color) 
	
	_regen_lock_editors()
	_setting_to_data = false

func set_curse(val: bool, which: Enums.curse) -> void:
	door_data.set_curse(which, val)

func _update_door_size() -> void:
	if _setting_to_data: return
	door_data.size = Vector2i(roundi(width.value), roundi(height.value))
	_update_lock_editors_door_size()

func _update_door_amount() -> void:
	if _setting_to_data: return
	if real_copies.value == 0 and imaginary_copies.value == 0:
		if real_copies.value != door_data.amount.real_part:
			real_copies.value = -door_data.amount.real_part
		if imaginary_copies.value != door_data.amount.imaginary_part:
			imaginary_copies.value = -door_data.amount.imaginary_part
		return
	# Support for infinity
	var real := int(real_copies.value)
	var img := int(imaginary_copies.value)
	if real == real_copies.max_value:
		real = Enums.INT_MAX
	if real == real_copies.min_value:
		real = Enums.INT_MIN
	if img == imaginary_copies.max_value:
		img = Enums.INT_MAX
	if img == imaginary_copies.min_value:
		img = Enums.INT_MIN
	door_data.amount.set_to(real, img)

func _update_door_color(color: Enums.colors) -> void:
	if _setting_to_data: return
	door_data.outer_color = color

func _regen_lock_editors() -> void:
	for child in lock_editor_parent.get_children():
		child.queue_free()
	var i := 1
	for lock_data in door_data.locks:
		var lock_editor: LockEditor = LOCK_EDITOR.instantiate()
		lock_editor.lock_number = i
		lock_editor.door_size = door_data.size
		lock_editor.lock_data = lock_data
		lock_editor.delete.connect(_delete_lock.bind(lock_editor))
		lock_editor_parent.add_child(lock_editor)
		i += 1
	add_lock.text = "Add Lock %d" % i

func _update_lock_editors_door_size() -> void:
	if _setting_to_data: return
	for editor in lock_editor_parent.get_children():
		editor.door_size = door_data.size

func _add_new_lock() -> void:
	var new_lock := LockData.new()
	new_lock.color = door_data.outer_color
	if door_data.outer_color == Enums.colors.gate:
		if lock_editor_parent.get_child_count() != 0:
			new_lock.color = lock_editor_parent.get_child(-1).lock.lock_data.color
		else:
			new_lock.color = Enums.colors.white
	door_data.add_lock(new_lock)
	
	var lock_editor: LockEditor = LOCK_EDITOR.instantiate()
	lock_editor.editor_data = editor_data
	var i := lock_editor_parent.get_child_count() + 1
	lock_editor.lock_number = i
	lock_editor.door_size = door_data.size
	lock_editor.lock_data = new_lock
	lock_editor.delete.connect(_delete_lock.bind(lock_editor))
	lock_editor_parent.add_child(lock_editor)
	
	add_lock.text = "Add Lock %d" % (i + 1)

func _delete_lock(which: LockEditor) -> void:
	var i := which.lock_number - 1
	door_data.remove_lock_at(i)
	var lock_editors := lock_editor_parent.get_children()
	lock_editors[i].queue_free()
	for j in range(i+1, lock_editors.size()):
		lock_editors[j].lock_number = j
	add_lock.text = "Add Lock %d" % (lock_editors.size())
