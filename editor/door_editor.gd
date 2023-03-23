extends Control

@onready var door: MarginContainer = %Door

@onready var ice_checkbox: CheckBox = %IceCheckbox
@onready var erosion_checkbox: CheckBox = %ErosionCheckbox
@onready var paint_checkbox: CheckBox = %PaintCheckbox
@onready var ice_button: Button = %IceButton
@onready var erosion_button: Button = %ErosionButton
@onready var paint_button: Button = %PaintButton


func _ready() -> void:
	ice_button.tooltip_text = "Ice curse, broken with 1 red key or more."
	erosion_button.tooltip_text = "Erosion curse, broken with 5 green keys or more."
	paint_button.tooltip_text = "Paint curse, broken with 3 blue keys or more."
	ice_button.toggled.connect(ice_checkbox.set_pressed_no_signal)
	ice_button.toggled.connect(set_curse.bind(Enums.curse.ice))
	erosion_button.toggled.connect(erosion_checkbox.set_pressed_no_signal)
	erosion_button.toggled.connect(set_curse.bind(Enums.curse.erosion))
	paint_button.toggled.connect(paint_checkbox.set_pressed_no_signal)
	paint_button.toggled.connect(set_curse.bind(Enums.curse.paint))

func set_curse(val: bool, which: Enums.curse) -> void:
	door.door_data.set_curse(which, val)
