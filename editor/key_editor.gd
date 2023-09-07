@tool
extends MarginContainer
class_name KeyEditor

@export var key_data: KeyData:
	set(val):
		key_data = val.duplicated()
		if not is_node_ready(): await ready
		# TODO: Allow editing keys in the level (currently not done to be consistent with door editing)
		key.key_data = key_data
		_set_to_key_data()
@onready var key: Key = %key
@onready var color_choice: ColorChoiceEditor = %ColorChoice
@onready var type_choice: OptionButton = %TypeChoice
@onready var amount: MarginContainer = %Amount
@onready var real_amount: SpinBox = %RealAmount
@onready var imaginary_amount: SpinBox = %ImaginaryAmount

func _init() -> void:
	if not is_instance_valid(key_data):
		key_data = KeyData.new()
		key_data.color = Enums.colors.white

func _ready() -> void:
	key.key_data = key_data
	
	color_choice.changed_color.connect(_update_key_color)
	
	type_choice.clear()
	for key_type in Enums.KEY_TYPE_NAMES.keys():
		type_choice.add_item(Enums.KEY_TYPE_NAMES[key_type].capitalize(), key_type)
	type_choice.item_selected.connect(_update_key_type.unbind(1))
	
	real_amount.value_changed.connect(_update_key_amount.unbind(1))
	imaginary_amount.value_changed.connect(_update_key_amount.unbind(1))
	
	_set_to_key_data()

func _set_to_key_data() -> void:
	amount.visible = key_data.type in [Enums.key_types.add, Enums.key_types.exact]
	color_choice.set_to_color(key_data.color)
	type_choice.selected = type_choice.get_item_index(key_data.type)
	real_amount.value = key_data.amount.real_part
	imaginary_amount.value = key_data.amount.imaginary_part

func _update_key_color(color: Enums.colors) -> void:
	key_data.color = color

func _update_key_type() -> void:
	key_data.type = type_choice.get_item_id(type_choice.selected)
	amount.visible = key_data.type in [Enums.key_types.add, Enums.key_types.exact]

func _update_key_amount() -> void:
	key_data.amount.set_to(int(real_amount.value), int(imaginary_amount.value))
