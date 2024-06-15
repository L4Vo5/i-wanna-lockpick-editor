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
@onready var key: Key = %key
@onready var color_choice: ColorChoiceEditor = %ColorChoice
@onready var type_choice: OptionButton = %TypeChoice
@onready var amount: MarginContainer = %Amount
@onready var real_amount: SpinBox = %RealAmount
@onready var imaginary_amount: SpinBox = %ImaginaryAmount
@onready var is_infinite: CheckBox = %IsInfinite

func _init() -> void:
	data = KeyData.new()
	data.color = Enums.colors.white

func _ready() -> void:
	key.data = data
	
	color_choice.changed_color.connect(_update_key.unbind(1))
	
	type_choice.clear()
	for key_type in Enums.KEY_TYPE_NAMES.keys():
		type_choice.add_item(Enums.KEY_TYPE_NAMES[key_type].capitalize(), key_type)
	type_choice.item_selected.connect(_update_key.unbind(1))
	
	real_amount.value_changed.connect(_update_key.unbind(1))
	imaginary_amount.value_changed.connect(_update_key.unbind(1))
	is_infinite.pressed.connect(_update_key)
	
	_set_to_key_data()

func _set_to_key_data() -> void:
	color_choice.set_to_color(data.color)
	type_choice.selected = type_choice.get_item_index(data.type)
	real_amount.value = data.amount.real_part
	imaginary_amount.value = data.amount.imaginary_part
	is_infinite.button_pressed = data.is_infinite
	amount.visible = data.type in [Enums.key_types.add, Enums.key_types.exact]

func _update_key() -> void:
	data.color = color_choice.color
	data.type = type_choice.get_item_id(type_choice.selected)
	data.is_infinite = is_infinite.button_pressed
	data.amount.set_to(int(real_amount.value), int(imaginary_amount.value))
	amount.visible = data.type in [Enums.key_types.add, Enums.key_types.exact]
