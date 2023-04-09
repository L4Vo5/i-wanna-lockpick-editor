@tool
extends MarginContainer
class_name LockEditor

@export var lock_data: LockData:
	set(val):
		if lock_data == val: return
		if is_instance_valid(lock_data):
			lock_data.changed_minimum_size.disconnect(_update_min_size)
		lock_data = val
		if is_instance_valid(lock_data):
			lock_data.changed_minimum_size.connect(_update_min_size)
		if not is_ready: await ready
		arrangement_chooser.lock_data = lock_data
		lock.lock_data = val
		set_to_lock()
@onready var lock: Lock = %Lock
@onready var color_choice: OptionButton = %ColorChoice
@onready var type_choice: OptionButton = %TypeChoice
@onready var requirement_parent: MarginContainer = %Requirement
@onready var amount: SpinBox = %Amount
@onready var is_imaginary: CheckBox = %IsImaginary
@onready var arrangement_chooser: MarginContainer = %ArrangementChooser
@onready var width: SpinBox = %Width
@onready var height: SpinBox = %Height
@onready var fit: CheckBox = %Fit
@onready var lock_n: Label = %LockN
@export var lock_number := 1:
	set(val):
		if not is_ready: await ready
		lock_number = val
		lock_n.text = "Lock %d" % lock_number

var is_ready := false
func _ready() -> void:
	is_ready = true
	width.get_line_edit().add_theme_constant_override(&"minimum_character_width", 2)
	height.get_line_edit().add_theme_constant_override(&"minimum_character_width", 2)
	amount.get_line_edit().add_theme_constant_override(&"minimum_character_width", 2)
	width.get_line_edit().expand_to_text_length = true
	height.get_line_edit().expand_to_text_length = true
	amount.get_line_edit().expand_to_text_length = true
	color_choice.clear()
	
	for key in Enums.COLOR_NAMES.keys():
		if key == Enums.colors.none: continue
		color_choice.add_item(Enums.COLOR_NAMES[key].capitalize(), key)
	color_choice.item_selected.connect(_update_lock_color.unbind(1))
	
	type_choice.clear()
	for key in Enums.LOCK_TYPE_NAMES.keys():
		type_choice.add_item(Enums.LOCK_TYPE_NAMES[key].capitalize(), key)
	type_choice.item_selected.connect(_update_lock_type.unbind(1))
	
	amount.value_changed.connect(_update_lock_amount.unbind(1))
	is_imaginary.pressed.connect(_update_is_imaginary)
	
	width.value_changed.connect(_update_lock_size.unbind(1))
	height.value_changed.connect(_update_lock_size.unbind(1))
	
	arrangement_chooser.changed_arrangement.connect(_on_arrangement_changed)
	fit.pressed.connect(_on_arrangement_changed)
	
	set_to_lock()
	lock_n.text = "Lock %d" % lock_number
	
	fit.editor_description = "Makes the lock as small as possible"

# Sets the different controls to the lockdata's data
func set_to_lock() -> void:
	color_choice.selected = color_choice.get_item_index(lock_data.color)
	type_choice.selected = type_choice.get_item_index(lock_data.lock_type)
	var full_amount := lock_data.get_complex_amount()
	amount.value = full_amount.real_part + full_amount.imaginary_part
	last_amount_value = amount.value
	width.min_value = lock_data.minimum_size.x
	height.min_value = lock_data.minimum_size.y
	width.value = lock_data.size.x
	height.value = lock_data.size.y

func _update_min_size() -> void:
	if not is_ready: await ready
	width.min_value = lock_data.minimum_size.x
	height.min_value = lock_data.minimum_size.y

func _update_lock_size() -> void:
	lock_data.size = Vector2i(width.value, height.value)

func _update_lock_color() -> void:
	lock_data.color = color_choice.get_item_id(color_choice.selected)

func _update_lock_type() -> void:
	lock_data.lock_type = type_choice.get_item_id(type_choice.selected)
	requirement_parent.visible = lock_data.lock_type == Enums.lock_types.normal

var last_amount_value := 0
func _update_lock_amount() -> void:
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
		last_amount_value = amount.value
		return
	lock_data.magnitude = abs(amount.value)
	if amount.value < 0:
		lock_data.sign = Enums.sign.negative
	else:
		lock_data.sign = Enums.sign.positive
	last_amount_value = amount.value

func _update_is_imaginary() -> void:
	if is_imaginary.button_pressed:
		lock_data.value_type = Enums.value.imaginary
	else:
		lock_data.value_type = Enums.value.real

func _on_arrangement_changed() -> void:
	if fit.button_pressed:
		width.value = lock_data.minimum_size.x
		height.value = lock_data.minimum_size.y
