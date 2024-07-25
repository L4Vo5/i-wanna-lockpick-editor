extends Node2D
class_name HoverHighlight

signal adapted_to(obj: Node)
signal stopped_adapting

var current_obj: CanvasItem:
	set(val):
		val = val if is_instance_valid(val) else null
		if current_obj == val: return
		current_obj = val
		update_line()
		if current_obj:
			adapted_to.emit(current_obj)
		else:
			stopped_adapting.emit()
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
	current_obj = null

func _hide_all() -> void:
	line.hide()

func adapt_to(obj: Node) -> void:
	current_obj = obj

func update_line() -> void:
	if not current_obj:
		line.hide()
		return
	line.show()
	var size := Vector2i(32, 32)
	if current_obj is Door:
		var data: DoorData = current_obj.data
		assert(is_instance_valid(data))
		size = data.size
	line.show()
	line.global_position = current_obj.global_position
	line.clear_points()
	line.add_point(Vector2(0, 0))
	line.add_point(Vector2(size.x, 0))
	line.add_point(Vector2(size.x, size.y))
	line.add_point(Vector2(0, size.y))
	line.add_point(Vector2(0, 0))
