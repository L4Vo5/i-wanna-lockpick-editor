@tool
extends Control
class_name DoorEditor

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
@onready var color_choice: OptionButton = %ColorChoice

## the idea is that non-standard-levels should be able to exist, maybe, but they must be labeled as such (for example doors with non-32-multiple sizes, or a door starting out browned or with a different glitch color. things that are valid but.. not standard)
## unimplemented for now tho lol
var non_standard_mode := false

func _ready() -> void:
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
	
	width.value = door.door_data.size.x
	height.value = door.door_data.size.y
	width.value_changed.connect(_update_door_size.unbind(1))
	height.value_changed.connect(_update_door_size.unbind(1))
	
	real_copies.value = door.door_data.amount.real_part
	imaginary_copies.value = door.door_data.amount.imaginary_part
	real_copies.value_changed.connect(_update_door_amount.unbind(1))
	imaginary_copies.value_changed.connect(_update_door_amount.unbind(1))
	
	color_choice.clear()
	for key in Enums.COLOR_NAMES.keys():
		if key == Enums.colors.none: continue
		color_choice.add_item(Enums.COLOR_NAMES[key].capitalize(), key)
	color_choice.selected = color_choice.get_item_index(door.door_data.outer_color) 
	color_choice.item_selected.connect(_update_door_color.unbind(1))

func set_curse(val: bool, which: Enums.curse) -> void:
	door.door_data.set_curse(which, val)

func _update_door_size() -> void:
	door.door_data.size = Vector2i(roundi(width.value), roundi(height.value))

func _update_door_amount() -> void:
	door.door_data.amount.set_to(real_copies.value, imaginary_copies.value)

func _update_door_color() -> void:
	door.door_data.outer_color = color_choice.get_item_id(color_choice.selected)
