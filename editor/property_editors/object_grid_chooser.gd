@tool
extends Container
class_name ObjectGridChooser
## Children will be distributed as horizontally as possible on a grid.
## They'll also have their mouse filter set to MOUSE_FILTER_IGNORE

signal object_selected(obj: Node)

@export var object_size := 32:
	set = set_object_size
@export var selected_color := Color(1, 1, 1, 0.3):
	set = set_selected_color
## the separation in pixels between objects
@export var object_sep := 10:
	set = set_object_sep
## the minimum amount of rows to force
@export var min_rows := 1:
	set = set_min_rows

## the currently selected child
var selected_object: Control:
	set(val):
		if not val:
			if get_child_count() != 0:
				val = get_child(0)
		if selected_object == val: return
		selected_object = val
		_reposition_color_rect()
		object_selected.emit(selected_object)

# the full length in pixels that a object will "occupy"
# taking into account [member object_size] and [member object_sep]
var _object_occupied_size: int:
	get:
		return object_size + object_sep
# how many objects there'll be per row (except the smallest row)
var _objects_per_row: int
# free space in the row with the most objects, after placing the objects
var _free_space: float
# amount of rows we're actually using
var _row_count: int = -1

var _is_clicking_inside := false

var _color_rect: ColorRect

func _ready() -> void:
	_color_rect = ColorRect.new()
	add_child(_color_rect, 0, Node.INTERNAL_MODE_FRONT)
	_color_rect.color = selected_color
	_color_rect.size = Vector2(object_size, object_size)
	set_object_size(object_size)
	set_selected_color(selected_color)
	selected_object = selected_object

func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_redistribute_children()

func set_object_size(new_size: int) -> void:
	object_size = new_size
	if _color_rect:
		_color_rect.size = Vector2(object_size, object_size)
	queue_sort()

func set_selected_color(new_color: Color) -> void:
	selected_color = new_color
	if _color_rect:
		_color_rect.color = selected_color

func set_object_sep(new_sep: int) -> void:
	object_sep = new_sep
	queue_sort()

func set_min_rows(new_min_rows: int) -> void:
	min_rows = new_min_rows
	if min_rows > _row_count:
		queue_sort()

func clear() -> void:
	while get_child_count() != 0:
		var child := get_child(-1)
		remove_child(child)
		child.queue_free()

func _redistribute_children() -> void:
	var max_objects_per_row := floori(size.x / _object_occupied_size)
	if max_objects_per_row <= 0: max_objects_per_row = 1
	# Round up so there's always at least 1 row
	_row_count = ((get_child_count() + max_objects_per_row - 1) / max_objects_per_row)
	_row_count = maxi(_row_count, min_rows)
	# Also round up to get the amount of objects in the longest row
	_objects_per_row = (get_child_count() + _row_count - 1) / _row_count
	
	_free_space = size.x - (_objects_per_row * object_size + (_objects_per_row - 1) * object_sep)
	custom_minimum_size.y = _row_count * _object_occupied_size
	custom_minimum_size.x = _object_occupied_size
	for i in get_child_count():
		var x := _free_space / 2.0 + (i % _objects_per_row) * _object_occupied_size
		var y := (i / _objects_per_row) * _object_occupied_size + object_sep / 2.0
		var object := get_child(i)
		object.position = Vector2(x, y)
		if object is Control:
			object.size = Vector2(object_size, object_size)
			object.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reposition_color_rect()

func _get_configuration_warnings() -> PackedStringArray:
	for child in get_children():
		if not child is Control:
			return ["All children should be Control nodes"]
	return []

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var mouse_pos := get_local_mouse_position()
				if _is_point_inside(mouse_pos):
					_detect_selected_object(mouse_pos)
					accept_event()
					_is_clicking_inside = true
			else:
				_is_clicking_inside = false
	elif (event is InputEventMouseMotion) and _is_clicking_inside:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_is_clicking_inside = false
			return
		var mouse_pos := get_local_mouse_position()
		_detect_selected_object(mouse_pos)
		accept_event()

func _detect_selected_object(mouse_pos: Vector2) -> void:
	var virtual_rect := Rect2(
		Vector2(_free_space / 2.0, 0), 
			Vector2(
				size.x - _free_space,
				_row_count * _object_occupied_size
			)
		)
	var grid_pos := Vector2i((mouse_pos - virtual_rect.position) / _object_occupied_size)
	grid_pos.x = clampi(grid_pos.x, 0, _objects_per_row - 1)
	grid_pos.y = clampi(grid_pos.y, 0, _row_count - 1)
	var i := grid_pos.x + grid_pos.y * _objects_per_row
	i = clampi(i, 0, get_child_count() - 1)
	selected_object = get_child(i)
	_reposition_color_rect()

func _is_point_inside(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(point)

func _reposition_color_rect() -> void:
	_color_rect.size = Vector2.ONE * (object_size)
	# In case it's null, sets it to the first child.
	# (unless there are no children)
	selected_object = selected_object
	if not is_instance_valid(selected_object):
		print("AW")
		print(selected_object)
		print(get_child_count())
		_color_rect.hide()
	else:
		_color_rect.show()
		_color_rect.position = selected_object.position
