extends Node2D
class_name HoverHighlight

signal adapted_to(obj: Node)
signal stopped_adapting

var current_obj: Node:
	set(val):
		current_obj = val if is_instance_valid(val) else null
	get:
		if not is_instance_valid(current_obj) and current_obj != null:
			stop_adapting()
		return current_obj

@onready var line: Line2D = %Line2D
@export var color: Color:
	set(val):
		color = val
		modulate = color
@export var width := 2:
	set(val):
		width = val
		if not is_node_ready(): return
		adjust_to_width()

func _ready() -> void:
	_hide_all()
	adjust_to_width()

func adjust_to_width() -> void:
	line.width = width

func stop_adapting_to(obj: Object) -> void:
	if obj == current_obj:
		stop_adapting()

func stop_adapting() -> void:
	_hide_all()
	current_obj = null
	stopped_adapting.emit()

func _hide_all() -> void:
	line.hide()

func is_adapting() -> bool:
	return current_obj == null

func adapt_to(obj: Node) -> void:
	if not is_instance_valid(obj):
		stop_adapting()
		return
	# we allow the same object to be passed several times, in case position needs to be adjusted
#	if obj == current_obj:
#		return
	current_obj = obj
	_hide_all()
	var offset := Vector2(0, 0)
	var size := Vector2i(32, 32)
	if obj is Door:
		var data: DoorData = obj.door_data
		assert(is_instance_valid(data))
		size = data.size
	if obj is SalvagePoint:
		offset = Vector2(-16, -32)
	line.show()
	line.global_position = obj.global_position
	line.clear_points()
	line.add_point(offset + Vector2(0, 0))
	line.add_point(offset + Vector2(size.x, 0))
	line.add_point(offset + Vector2(size.x, size.y))
	line.add_point(offset + Vector2(0, size.y))
	line.add_point(offset + Vector2(0, 0))
	adapted_to.emit(obj)
