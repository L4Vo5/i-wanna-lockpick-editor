@tool
extends MarginContainer
class_name Door

var LOCK := preload("res://rendering/doors_locks/lock_visual.tscn")

@export var door_data: DoorData

@onready var colored_center := %ColoredCenter as NinePatchRect
@onready var frame := %Frame as NinePatchRect
@onready var static_body := %StaticBody2D as StaticBody2D
@onready var lock_holder := %LockHolder as Control

@onready var ice: MarginContainer = %Ice
@onready var paint: TextureRect = %Paint
@onready var erosion: MarginContainer = %Erosion
@onready var brown_curse: Control = %BrownCurse

func _ready() -> void:
	static_body.disable_mode = CollisionObject2D.DISABLE_MODE_REMOVE
	if not Global.in_editor:
		door_data = door_data.duplicate(true)

# DEBUG: This shouldn't be every frame lol
func _physics_process(_delta: float) -> void:
	size = door_data.size
	static_body.scale = size
	colored_center.texture = Rendering.get_door_color_texture(door_data.outer_color)
	frame.texture = Rendering.get_door_frame_texture(Enums.sign.positive if door_data.amount[0].real_part >= 0 else Enums.sign.negative)
	update_locks()
	update_curses()

func update_locks() -> void:
	for lock in lock_holder.get_children():
		lock.queue_free()
	for lock in door_data.locks:
		var new_lock := LOCK.instantiate()
		new_lock.lock_data = lock
		lock_holder.add_child(new_lock)

func update_curses() -> void:
	ice.visible = door_data.curses[Enums.curses.ice]
	erosion.visible = door_data.curses[Enums.curses.eroded]
	paint.visible = door_data.curses[Enums.curses.painted]
	brown_curse.visible = door_data.curses[Enums.curses.brown]

func try_open() -> void:
	door_data.try_open()
	if door_data.amount[0].is_zero():
		hide()
		static_body.process_mode = Node.PROCESS_MODE_DISABLED

# do the effects for the curses
func break_curse_ice() -> void:
	if not door_data.curses[Enums.curses.ice]: return
	door_data.curses[Enums.curses.ice] = false

func break_curse_eroded() -> void:
	if not door_data.curses[Enums.curses.eroded]: return
	door_data.curses[Enums.curses.eroded] = false

func break_curse_painted() -> void:
	if not door_data.curses[Enums.curses.painted]: return
	door_data.curses[Enums.curses.painted] = false

func curse_brown() -> void:
	if door_data.curses[Enums.curses.brown]: return
	door_data.curses[Enums.curses.brown] = true

func break_curse_brown() -> void:
	if not door_data.curses[Enums.curses.brown]: return
	door_data.curses[Enums.curses.brown] = false
