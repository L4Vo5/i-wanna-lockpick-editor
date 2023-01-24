@tool
extends MarginContainer
class_name Door

@export var door_data: DoorData

@onready var colored_center := %ColoredCenter as NinePatchRect
@onready var frame := %Frame as NinePatchRect
@onready var static_body := %StaticBody2D as StaticBody2D

# DEBUG: This shouldn't be every frame lol
func _process(_delta: float) -> void:
	colored_center.texture = DoorRendering.get_door_color_texture(door_data.outer_color)
	frame.texture = DoorRendering.get_door_frame_texture(Enums.sign.positive if door_data.amount[0].real_part >= 0 else Enums.sign.negative)
	static_body.scale = size
