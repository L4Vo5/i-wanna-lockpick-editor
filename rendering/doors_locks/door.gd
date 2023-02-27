extends MarginContainer
class_name Door

var LOCK := preload("res://rendering/doors_locks/lock_visual.tscn")

@export var door_data: DoorData

@onready var colored_center := %ColoredCenter as NinePatchRect
@onready var frame := %Frame as NinePatchRect
@onready var static_body := %StaticBody2D as StaticBody2D
@onready var lock_holder := %LockHolder as Control

func _ready() -> void:
	pass

# DEBUG: This shouldn't be every frame lol
func _process(_delta: float) -> void:
	size = door_data.size
	static_body.scale = size
	colored_center.texture = DoorRendering.get_door_color_texture(door_data.outer_color)
	frame.texture = DoorRendering.get_door_frame_texture(Enums.sign.positive if door_data.amount[0].real_part >= 0 else Enums.sign.negative)
	update_locks()

func update_locks() -> void:
	for lock in lock_holder.get_children():
		lock.queue_free()
	for lock in door_data.locks:
		var new_lock := LOCK.instantiate()
		lock_holder.add_child(new_lock)
		new_lock.lock_data = lock
