@tool
extends MarginContainer

@export var door_data: DoorData

@onready var colored_center := %ColoredCenter as NinePatchRect
@onready var frame := %Frame as NinePatchRect

# This shouldn't be every frame lol
func _process(_delta: float) -> void:
	colored_center.texture = DoorRendering.get_door_color_texture(door_data.outer_color)
	frame.texture = DoorRendering.get_door_frame_texture(Enums.sign.positive if door_data.real_amount >= 0 else Enums.sign.negative)
