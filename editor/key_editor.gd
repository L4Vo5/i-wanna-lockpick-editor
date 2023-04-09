@tool
extends MarginContainer
class_name KeyEditor

@onready var key: Key = %key
@onready var color_choice: OptionButton = %ColorChoice
@onready var type_choice: OptionButton = %TypeChoice
@onready var amount: MarginContainer = %Amount
@onready var real_amount: SpinBox = %RealAmount
@onready var imaginary_amount: SpinBox = %ImaginaryAmount

func _ready() -> void:
	color_choice.clear()
	for key in Enums.COLOR_NAMES.keys():
		if key == Enums.colors.none: continue
		color_choice.add_item(Enums.COLOR_NAMES[key].capitalize(), key)
	color_choice.selected = color_choice.get_item_index(key.key_data.color)
	color_choice.item_selected.connect(_update_key_color.unbind(1))
	
	type_choice.clear()
	for key in Enums.KEY_TYPE_NAMES.keys():
		type_choice.add_item(Enums.KEY_TYPE_NAMES[key].capitalize(), key)
	type_choice.selected = type_choice.get_item_index(key.key_data.type)
	type_choice.item_selected.connect(_update_key_type.unbind(1))
	amount.visible = key.key_data.type in [Enums.key_types.add, Enums.key_types.exact]
	
	real_amount.value = key.key_data.amount.real_part
	imaginary_amount.value = key.key_data.amount.imaginary_part
	real_amount.value_changed.connect(_update_key_amount.unbind(1))
	imaginary_amount.value_changed.connect(_update_key_amount.unbind(1))

func _update_key_color() -> void:
	key.key_data.color = color_choice.get_item_id(color_choice.selected)

func _update_key_type() -> void:
	key.key_data.type = type_choice.get_item_id(type_choice.selected)
	amount.visible = key.key_data.type in [Enums.key_types.add, Enums.key_types.exact]

func _update_key_amount() -> void:
	key.key_data.amount.set_to(real_amount.value, imaginary_amount.value)
