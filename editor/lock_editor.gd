@tool
extends MarginContainer
class_name LockEditor

signal delete
@export var lock_data: LockData:
	set(val):
		if lock_data == val: return
		if is_instance_valid(lock_data):
			lock_data.changed_minimum_size.disconnect(_update_min_size)
		lock_data = val
		if is_instance_valid(lock_data):
			lock_data.changed_minimum_size.connect(_update_min_size)
		if not is_node_ready(): await ready
		arrangement_chooser.lock_data = lock_data
		lock.lock_data = val
		_set_to_lock_data()
@onready var lock: Lock = %Lock
@onready var color_choice: ColorChoiceEditor = %ColorChoice
@onready var lock_type_choice: LockTypeEditor = %LockTypeChoice
@onready var requirement_parent: HBoxContainer = %Requirement
@onready var amount: SpinBox = %Amount
@onready var is_imaginary: CheckBox = %IsImaginary
@onready var is_negative: CheckBox = %IsNegative
@onready var arrangement_chooser: MarginContainer = %ArrangementChooser
@onready var width: SpinBox = %Width
@onready var height: SpinBox = %Height
@onready var fit: CheckBox = %Fit
@onready var lock_n: Label = %LockN
@onready var delete_button: Button = %Delete
@onready var position_x: SpinBox = %X
@onready var position_y: SpinBox = %Y
@export var lock_number := 1:
	set(val):
		if not is_node_ready(): await ready
		lock_number = val
		lock_n.text = "Lock %d" % lock_number
@export var door_size := Vector2i(32, 32):
	set(val):
		if door_size == val: return
		door_size = val
		_update_max_pos()
		_update_max_size()

var editor_data: EditorData

func _ready() -> void:
	delete_button.pressed.connect(func(): delete.emit())
	width.get_line_edit().add_theme_constant_override(&"minimum_character_width", 2)
	height.get_line_edit().add_theme_constant_override(&"minimum_character_width", 2)
	amount.get_line_edit().add_theme_constant_override(&"minimum_character_width", 2)
	position_x.get_line_edit().add_theme_constant_override(&"minimum_character_width", 2)
	position_y.get_line_edit().add_theme_constant_override(&"minimum_character_width", 2)
	width.get_line_edit().expand_to_text_length = true
	height.get_line_edit().expand_to_text_length = true
	amount.get_line_edit().expand_to_text_length = true
	position_x.get_line_edit().expand_to_text_length = true
	position_y.get_line_edit().expand_to_text_length = true
	
	color_choice.changed_color.connect(_update_lock_color)
	lock_type_choice.changed_type.connect(_update_lock_type)
	
	amount.value_changed.connect(_update_lock_amount.unbind(1))
	is_imaginary.pressed.connect(_update_is_imaginary)
	is_negative.pressed.connect(_update_is_negative)
	
	width.value_changed.connect(_update_lock_size.unbind(1))
	height.value_changed.connect(_update_lock_size.unbind(1))
	
	arrangement_chooser.editor_data = editor_data
	arrangement_chooser.changed_arrangement.connect(_update_arrangement)
	fit.pressed.connect(_update_arrangement)
	
	position_x.value_changed.connect(_update_position.unbind(1))
	position_y.value_changed.connect(_update_position.unbind(1))
	
	lock_n.text = "Lock %d" % lock_number
	
	fit.editor_description = "Makes the lock as small as possible"
	
	_set_to_lock_data()
	_update_max_size()

# See _setting_to_data in DoorEditor
var _setting_to_data := false
# Sets the different controls to the lockdata's data
func _set_to_lock_data() -> void:
	_setting_to_data = true
	color_choice.set_to_color(lock_data.color)
	lock_type_choice.color = lock_data.color
	lock_type_choice.type = lock_data.lock_type
	var full_amount := lock_data.get_complex_amount()
	amount.value = full_amount.real_part + full_amount.imaginary_part
	is_negative.button_pressed = amount.value < 0
	last_amount_value = int(amount.value)
	width.min_value = lock_data.minimum_size.x
	height.min_value = lock_data.minimum_size.y
	width.value = lock_data.size.x
	height.value = lock_data.size.y
	# This goes first so changing the position doesn't clamp the locks
	position_x.value = lock_data.position.x
	position_y.value = lock_data.position.y
	_setting_to_data = false
	_update_max_pos()

func _update_min_size() -> void:
	if _setting_to_data: return
	if not is_node_ready(): await ready
	width.min_value = lock_data.minimum_size.x
	height.min_value = lock_data.minimum_size.y
	

func _update_lock_size() -> void:
	if _setting_to_data: return
	lock_data.size = Vector2i(int(width.value), int(height.value))
	_update_max_pos()

func _update_lock_color(color: Enums.colors) -> void:
	if _setting_to_data: return
	lock_data.color = color_choice.color
	lock_data.emit_changed()
	lock_type_choice.color = color

func _update_lock_type() -> void:
	if _setting_to_data: return
	lock_data.lock_type = lock_type_choice.type
	if lock_data.lock_type == Enums.lock_types.normal:
		arrangement_chooser.show()
		requirement_parent.show()
		for child in requirement_parent.get_children():
			child.show()
	elif lock_data.lock_type == Enums.lock_types.blast:
		arrangement_chooser.hide()
		requirement_parent.show()
		for child in requirement_parent.get_children():
			child.hide()
		is_negative.show()
		is_imaginary.show()
	else:
		arrangement_chooser.hide()
		requirement_parent.hide()
	lock_data.emit_changed()

var last_amount_value := 0
func _update_lock_amount() -> void:
	if _setting_to_data: return
	# special case: amount's value shouldn't be 0
	if amount.value == 0:
		if lock_data.sign == Enums.sign.positive:
			if last_amount_value == 1:
				amount.value = -1
			else:
				amount.value = 1
		elif last_amount_value == -1:
			amount.value = 1
		else:
			amount.value = -1
		last_amount_value = int(amount.value)
		return
	lock_data.magnitude = abs(amount.value)
	if amount.value < 0:
		lock_data.sign = Enums.sign.negative
		if not is_negative.button_pressed:
			is_negative.button_pressed = true
	else:
		lock_data.sign = Enums.sign.positive
		if is_negative.button_pressed:
			is_negative.button_pressed = false
	last_amount_value = int(amount.value)
	lock_data.emit_changed()
	arrangement_chooser.update_options()

func _update_is_imaginary() -> void:
	if _setting_to_data: return
	if is_imaginary.button_pressed:
		lock_data.value_type = Enums.value.imaginary
	else:
		lock_data.value_type = Enums.value.real
	lock_data.emit_changed()

func _update_is_negative() -> void:
	if _setting_to_data: return
	if is_negative.button_pressed:
		lock_data.sign = Enums.sign.negative
		if amount.value > 0:
			amount.value = -abs(amount.value)
	else:
		lock_data.sign = Enums.sign.positive
		if amount.value < 0:
			amount.value = abs(amount.value)
	lock_data.emit_changed()

func _update_arrangement() -> void:
	if _setting_to_data: return
	if fit.button_pressed:
		width.value = lock_data.minimum_size.x
		height.value = lock_data.minimum_size.y

func _update_position() -> void:
	if _setting_to_data: return
	if not is_node_ready(): await ready
	lock_data.position = Vector2i(roundi(position_x.value), roundi(position_y.value))

func _update_max_pos() -> void:
	if _setting_to_data: return
	if not is_node_ready(): await ready
	position_x.max_value = door_size.x - lock_data.size.x
	position_y.max_value = door_size.y - lock_data.size.y

func _update_max_size() -> void:
	if not is_node_ready(): await ready
	width.max_value = door_size.x
	height.max_value = door_size.y
