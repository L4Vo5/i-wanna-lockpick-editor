extends RefCounted
class_name SelectionSystem

var collision_system: CollisionSystem
var level_container: LevelContainer

## "set" of rect ids
var selection: Dictionary

var last_valid_offset: Vector2i
var offset: Vector2i
var collision_count: int

var moving_state: bool

## Adds a set of rectangles to the selection and updates the outline
func add_multiple_to_selection(ids: Dictionary, outline: SelectionOutline) -> void:
	assert(not moving_state, "Tried to modify selection during moving state")
	for id in ids:
		selection[id] = true
	for id in ids:
		var iter := collision_system._get_rect_tile_iter(collision_system.get_rect(id))
		outline.add_rectangle(iter, 1)
	outline.queue_redraw()

## Adds a rectangle to the selection and updates the outline
func add_to_selection(id: int, outline: SelectionOutline) -> void:
	assert(not moving_state, "Tried to modify selection during moving state")
	if selection.has(id):
		return
	selection[id] = true
	var iter := collision_system._get_rect_tile_iter(collision_system.get_rect(id))
	outline.add_rectangle(iter, 1)
	outline.queue_redraw()

func reset_selection() -> void:
	assert(not moving_state, "Tried to modify selection during moving state")
	selection.clear()

func remove_from_selection(id: int, outline: SelectionOutline) -> void:
	if not selection.has(id):
		return
	selection.erase(id)
	var iter := collision_system._get_rect_tile_iter(collision_system.get_rect(id))
	outline.add_rectangle(iter, -1)
	outline.queue_redraw()

func start_moving() -> void:
	if moving_state:
		return
	moving_state = true
	for id in selection:
		var iter := collision_system._get_rect_tile_iter(collision_system.get_rect(id))
		for x in range(iter.position.x, iter.end.x):
			for y in range(iter.position.y, iter.end.y):
				var rects: PackedInt64Array = collision_system._tile_to_rects[Vector2i(x, y)]
				rects.remove_at(rects.bsearch(id))
				if rects.is_empty():
					collision_system._tile_to_rects.erase(Vector2i(x, y))
	_recalculate_collision_count()

func _recalculate_collision_count() -> void:
	var level_rect := Rect2i(Vector2i.ZERO, level_container.editor_data.level_data.size / collision_system.tile_size)
	collision_count = 0
	for id in selection:
		var rect := collision_system.get_rect(id)
		rect.position += offset
		var old_iter := collision_system._get_rect_tile_iter(rect)
		var iter := old_iter.intersection(level_rect)
		collision_count += old_iter.get_area() - iter.get_area() # collision with border
		for x in range(iter.position.x, iter.end.x):
			for y in range(iter.position.y, iter.end.y):
				var pos := Vector2i(x, y)
				if collision_system._tile_to_rects.has(pos):
					var rects: PackedInt64Array = collision_system._tile_to_rects[pos]
					collision_count += rects.size()

func stop_moving() -> void:
	if not moving_state:
		return
	for id in selection:
		var rect := collision_system.get_rect(id)
		rect.position += last_valid_offset
		collision_system._rects[id] = rect
		var iter := collision_system._get_rect_tile_iter(rect)
		for x in range(iter.position.x, iter.end.x):
			for y in range(iter.position.y, iter.end.y):
				var pos := Vector2i(x, y)
				var rects: PackedInt64Array
				if not collision_system._tile_to_rects.has(pos):
					rects = PackedInt64Array()
					collision_system._tile_to_rects[pos] = rects
				else:
					rects = collision_system._tile_to_rects[pos]
				rects.push_back(id)
				rects.sort()
	moving_state = false
	offset = Vector2i.ZERO
	last_valid_offset = Vector2i.ZERO

## Try moving the selection.
## If valid is false, this will return false and will not reposition any objects.
## If true is returned, *always* update the actual position of the selected objects.
func move_selection(delta: Vector2i, valid: bool = true) -> bool:
	if not moving_state:
		offset = delta
		start_moving()
		if valid and collision_count == 0:
			last_valid_offset = offset
		return valid and collision_count == 0
	# TODO: naive solution, better later maybe
	offset += delta
	_recalculate_collision_count()
	
	assert(collision_count >= 0)
	if valid and collision_count == 0:
		last_valid_offset = offset
	return valid and collision_count == 0
