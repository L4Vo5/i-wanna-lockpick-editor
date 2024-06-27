@tool
extends MarginContainer
class_name KeyEditor

@export var data: KeyData:
	set(val):
		data = val.duplicated()
		if not is_node_ready(): await ready
		# TODO: Allow editing keys in the level (currently not done to be consistent with door editing)
		key.data = data
		_set_to_key_data()
@onready var key: KeyElement = %key
@onready var color_choice: ColorChoiceEditor = %ColorChoice
@onready var type_choice: ObjectGridChooser = %TypeChoice
@onready var amount: MarginContainer = %Amount
@onready var real_amount: SpinBox = %RealAmount
@onready var imaginary_amount: SpinBox = %ImaginaryAmount
@onready var is_infinite: CheckBox = %IsInfinite

var type_choice_keys := {}

const KEY = preload("res://level_elements/keys/key.tscn")

func _init() -> void:
	data = KeyData.new()
	data.color = Enums.colors.white
func _ready() -> void:
	key.data = data
	
	color_choice.changed_color.connect(_update_key.unbind(1))
	
	type_choice.clear()
	for key_type in Enums.KEY_TYPE_NAMES.keys():
		var new_key: KeyElement = KEY.instantiate()
		new_key.ignore_position = true
		type_choice_keys[key_type] = new_key
		new_key.data = KeyData.new()
		new_key.data.type = key_type
		type_choice.add_child(new_key, true)
	_update_type_choice_keys()
	type_choice.object_selected.connect(_update_key.unbind(1))
	
	real_amount.value_changed.connect(_update_key.unbind(1))
	imaginary_amount.value_changed.connect(_update_key.unbind(1))
	is_infinite.pressed.connect(_update_key)
	
	_set_to_key_data()

var _setting_to_data := false
func _set_to_key_data() -> void:
	_setting_to_data = true
	color_choice.set_to_color(data.color)
	real_amount.value = data.amount.real_part
	imaginary_amount.value = data.amount.imaginary_part
	is_infinite.button_pressed = data.is_infinite
	amount.visible = data.type in [Enums.key_types.add, Enums.key_types.exact]
	type_choice.selected_object = type_choice_keys[data.type]
	_update_type_choice_keys()
	_setting_to_data = false

func _update_key() -> void:
	if _setting_to_data: return
	data.color = color_choice.color
	if type_choice.selected_object:
		data.type = type_choice.selected_object.data.type
	data.is_infinite = is_infinite.button_pressed
	data.amount.set_to(int(real_amount.value), int(imaginary_amount.value))
	amount.visible = data.type in [Enums.key_types.add, Enums.key_types.exact]
	_update_type_choice_keys()

func _update_type_choice_keys() -> void:
	for key_element: KeyElement in type_choice_keys.values():
		key_element.data.color = key.data.color
