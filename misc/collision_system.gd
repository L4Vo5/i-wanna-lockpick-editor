@tool
extends RefCounted
class_name CollisionSystem
## Collision system, implemented manually, unfortunately.
##
## Hopefully it'll be fast enough, otherwise I can try getting fancy with the algorithms (particularly for big objects). As a last resort, I could always reimplement it in GDExtension. That'll complicate the build process, though.
##
## IMPORTANT: Please don't access any of the variables starting with _

## Size of each tile in the grid.
var tile_size := 16
var inv_tile_size := 1.0 / tile_size

# For each tile (Vector2i), what rects (int) are inside it. (PackedInt64Array)
var _tile_to_rects := {}
# For each rect id (int), the Rect2i it represents
# This could be useful in the future, but currently it isn't!
var _rects := {}
# For each rect id (int), the arbitrary associated data passed in by the client.
var _rects_data := {}

var _next_rect_id := 1

func _init(_tile_size: int) -> void:
	tile_size = _tile_size
	inv_tile_size = 1.0 / tile_size

func clear() -> void:
	_tile_to_rects.clear()
	_rects.clear()
	_rects_data.clear()
	_next_rect_id = 1

## Adds a rect to the system.
## Returns the unique id given to that rect.
func add_rect(rect: Rect2i, associated_data: Variant = null, custom_id := -1) -> int:
	var id := custom_id
	if custom_id == -1:
		id = _next_rect_id
		_next_rect_id += 1
	assert(not _rects.has(id))
	_rects[id] = rect
	
	var tile_iter := _get_rect_tile_iter(rect)
	
	for x in range(tile_iter.position.x, tile_iter.end.x):
		for y in range(tile_iter.position.y, tile_iter.end.y):
			if not _tile_to_rects.has(Vector2i(x, y)):
				_tile_to_rects[Vector2i(x,y)] = PackedInt64Array([id])
			else:
				_tile_to_rects[Vector2i(x,y)].push_back(id)
	
	_rects_data[id] = associated_data
	return id

## Removes the rect with the given id from the system.
func remove_rect(id: int) -> void:
	var rect: Rect2i = _rects.get(id)
	_rects.erase(id)
	_rects_data.erase(id)
	var tile_iter := _get_rect_tile_iter(rect)
	
	for x in range(tile_iter.position.x, tile_iter.end.x):
		for y in range(tile_iter.position.y, tile_iter.end.y):
			var arr: PackedInt64Array = _tile_to_rects[Vector2i(x, y)]
			arr.remove_at(arr.find(id))
			if arr.size() == 0:
				_tile_to_rects.erase(Vector2i(x, y))

## Useful when you want to preserve the id.
func change_rect(id: int, new_rect: Rect2i) -> void:
	var data = _rects_data[id]
	remove_rect(id)
	add_rect(new_rect, data, id)

## DON'T MODIFY THE RETURN VALUE
func get_rects() -> Dictionary:
	return _rects

func get_rect(id: int) -> Rect2i:
	return _rects[id]

func get_rect_data(id: int) -> Variant:
	return _rects_data[id]

func set_rect_data(id: int, value) -> void:
	_rects_data[id] = value

func is_rect_valid(id: int) -> bool:
	return _rects.has(id)

## Note: _in_grid functions only check if stuff occupies the tile in the grid, it doesn't actually check for proper overlap. A rect from (0,0) to (2,2) and one from (4, 4) to (6, 6) don't overlap, but if tile_size is 5 or more an _in_grid function will count them as overlapping. This gives way better performance than fully checking. Actual proper checking could be implemented if needed.

## Returns true if the given rect has a collision with a rect in the system.
func rect_has_collision_in_grid(rect: Rect2i) -> bool:
	var tile_iter := _get_rect_tile_iter(rect)
	
	for x in range(tile_iter.position.x, tile_iter.end.x):
		for y in range(tile_iter.position.y, tile_iter.end.y):
			if _tile_to_rects.has(Vector2i(x, y)):
				return true
	return false

## Returns true if the given rect has a collision with a rect in the system, UNLESS that collision is the excluded rect.
# (the _1 is because it's only 1 exclusion. potentially could add one that takes many exclusions through a dict)
func rect_has_collision_in_grid_excluding_1(rect: Rect2i, exclusion: int) -> bool:
	var tile_iter := _get_rect_tile_iter(rect)
	
	for x in range(tile_iter.position.x, tile_iter.end.x):
		for y in range(tile_iter.position.y, tile_iter.end.y):
			var arr = _tile_to_rects.get(Vector2i(x, y))
			if arr is PackedInt64Array:
				for id in arr:
					if id != exclusion:
						return true
	return false

## Returns true if the given point has a collision with a rect in the system.
func point_has_collision_in_grid(point: Vector2i) -> bool:
	var tile_pos := Vector2i((point * inv_tile_size).floor())
	return _tile_to_rects.has(tile_pos)

## Returns a dict where the keys are the ids of all the rects that interect with [rect]. The values are meaningless.
# (Turning it into a PackedInt64Array would've been needless work)
func get_rects_intersecting_rect_in_grid(rect: Rect2i) -> Dictionary:
	var tile_iter := _get_rect_tile_iter(rect)
	var dict := {}
	for x in range(tile_iter.position.x, tile_iter.end.x):
		for y in range(tile_iter.position.y, tile_iter.end.y):
			var arr = _tile_to_rects.get(Vector2i(x, y))
			if arr is PackedInt64Array:
				for id in arr:
					dict[id] = true
	return dict

## The array here is READ ONLY. Unless it's empty, duplicate it before modifying it.
func get_rects_containing_point_in_grid(point: Vector2i) -> PackedInt64Array:
	var tile_pos := Vector2i((point * inv_tile_size).floor())
	var arr = _tile_to_rects.get(tile_pos)
	if arr != null:
		return arr
	else:
		return []

# Returns a rect2i containing, in order:
# - The (inclusive) xy start of tiles this rect is in
# - The (exclusive) xy end of tiles this rect is in
# I don't like using floats, but this is seemingly the fastest method to do it (I tried others). Inlining the function should make it about twice as fast, if really needed (it's probably not).
# Rect2i and Vector2i use 32-bit integers, so there should be no precision concerns anyways, I think? since floats are 64-bit
static func get_rect_tile_iter(r: Rect2i, _inv_tile_size: float) -> Rect2i:
	var orig_end := r.end
	r.position = Vector2i((r.position * _inv_tile_size).floor())
	r.end = Vector2i((orig_end * _inv_tile_size).ceil())
	return r

func _get_rect_tile_iter(r: Rect2i) -> Rect2i:
	return get_rect_tile_iter(r, inv_tile_size)
