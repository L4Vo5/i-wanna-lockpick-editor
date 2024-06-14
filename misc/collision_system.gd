@tool
extends RefCounted
class_name CollisionSystem
## Collision system, implemented manually, unfortunately.
##
## Hopefully it'll be fast enough, otherwise I can try getting fancy with the algorithms (particularly for big objects). As a last resort, I could always reimplement it in GDExtension. That'll complicate the build process, though.
##
## IMPORTANT: Please don't access any of the variables starting with _

## Size of each tile in the grid.
var tile_size := 16:
	set(val):
		assert(false, "Changing grid tile size is currently unsupported.")
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
	assert(_tile_size == 16)
	return
	tile_size = _tile_size
	inv_tile_size = 1.0 / tile_size

func clear() -> void:
	_tile_to_rects.clear()
	_rects.clear()
	_rects_data.clear()
	_next_rect_id = 1

## Adds a rect to the system.
## Returns the unique id given to that rect.
func add_rect(rect: Rect2i, associated_data: Variant = null) -> int:
	var id := _next_rect_id
	_next_rect_id += 1
	_rects[id] = rect
	
	var tile_iter := _get_rect_tile_iter(rect)
	
	for x in range(tile_iter.position.x, tile_iter.end.x):
		for y in range(tile_iter.position.y, tile_iter.end.y):
			if !(_tile_to_rects.has(Vector2i(x, y))):
				_tile_to_rects[Vector2i(x,y)] = PackedInt64Array()
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
			# This assumes the array will be in order, so you can't reuse ids.
			# and you CANNOT resize rects after adding them to the system.
			# (unless you take the necessary precautions to manually keep arrays sorted, but at that point bsearch isn't worth it)
			var arr: Array = _tile_to_rects[Vector2i(x, y)]
			arr.remove_at(arr.bsearch(id))
			if arr.size() == 0:
				_tile_to_rects.erase(Vector2i(x, y))

func get_rect_data(id: int) -> Variant:
	return _rects_data[id]

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
func _get_rect_tile_iter(r: Rect2i) -> Rect2i:
	var orig_end := r.end
	r.position = Vector2i((r.position * inv_tile_size).floor())
	r.end = Vector2i((orig_end * inv_tile_size).ceil())
	return r

# Silly test stuff. Ignore it.
func _run() -> void:
	const I32_MAX := Vector2i.MAX.x
	# Huge multiple of tile_size
	var _huge_mult := snappedi(I32_MAX/2, tile_size)
	# huge_mult_factor * tile_size = huge_mult
	var _huge_mult_factor := _huge_mult / tile_size
	var _huge_mult_vec := Vector4i(_huge_mult, _huge_mult, -_huge_mult, -_huge_mult)
	var _huge_mult_factor_vec := Vector4i(_huge_mult_factor, _huge_mult_factor, _huge_mult_factor, -_huge_mult_factor)
	var start := Time.get_ticks_msec()
	var end := Time.get_ticks_msec()
	var rect := Rect2i(99, 43, 17, 88)
	
	start = Time.get_ticks_msec()
	for i in range(-1000000, 2000000):
		pass
	end = Time.get_ticks_msec()
	print(end - start)
	start = Time.get_ticks_msec()
	var d = range(-1000000, 2000000)
	var e = d
	for i in d:
		pass
	end = Time.get_ticks_msec()
	print(end - start)
	start = Time.get_ticks_msec()
	var a = -1000000
	var b = 2000000
	for i in range(-a, b):
		pass
	end = Time.get_ticks_msec()
	print(end - start)
	
	const AMOUNT = 2_000_000
	
	start = Time.get_ticks_msec()
	for i in AMOUNT:
		(i+_huge_mult)/tile_size-_huge_mult_factor
	end = Time.get_ticks_msec()
	print("manual: " + str(end - start))
	
	start = Time.get_ticks_msec()
	for i in AMOUNT:
		floori(i/(tile_size as float))
	end = Time.get_ticks_msec()
	print("float+floor: " + str(end - start))
	var recip := 1.0 / tile_size
	start = Time.get_ticks_msec()
	for i in AMOUNT:
		floori(i*recip)
	end = Time.get_ticks_msec()
	print("floor+reciprocal (fastest!): " + str(end - start))
	
	print("Making sure they all agree")
	for i in AMOUNT:
		var aa := (i+_huge_mult)/tile_size-_huge_mult_factor
		var bb := floori(i/(tile_size as float))
		var cc := floori(i*recip)
		if !(aa == bb and bb == cc):
			print("They don't! %s %s %s" % [aa, bb, cc])
	print("Done")
	var r: Rect2i
	start = Time.get_ticks_msec()
	for i in AMOUNT:
		r = Rect2i(i,i,i,i)
		(Vector4i(
			i,
			i,
			i,
			i
		) + _huge_mult_vec) / tile_size + _huge_mult_factor_vec
	end = Time.get_ticks_msec()
	print("vec, manual: " + str(end - start))
	start = Time.get_ticks_msec()
	for i in AMOUNT:
		r = Rect2i(i,i,i,i)
		(Vector4i(
			r.position.x,
			r.position.y,
			r.end.x,
			r.end.y
		) + _huge_mult_vec) / tile_size + _huge_mult_factor_vec
	end = Time.get_ticks_msec()
	print("vec, manual (rect): " + str(end - start))
	start = Time.get_ticks_msec()
	for i in AMOUNT:
		r = Rect2i(i,i,i,i)
		Vector4i(
			floori(i*recip),
			floori(i*recip),
			floori(i*recip),
			floori(i*recip)
		)
	end = Time.get_ticks_msec()
	print("vec, floor + recip: " + str(end - start))
	start = Time.get_ticks_msec()
	for i in AMOUNT:
		r = Rect2i(i,i,i,i)
		Vector4i(
			floori((r.position.x)*recip),
			floori((r.position.y)*recip),
			ceili((r.end.x)*recip),
			ceili((r.end.y)*recip)
		)
	end = Time.get_ticks_msec()
	print("vec, floor + recip (rect): " + str(end - start))
	start = Time.get_ticks_msec()
	for i in AMOUNT:
		r = Rect2i(i,i,i,i)
		(Vector4(
			r.position.x,
			r.position.y,
			r.end.x,
			r.end.y
		) * recip).floor()
	end = Time.get_ticks_msec()
	print("vec, floor + recip (rect) on whole vector which doesn't even work since it has no ceil: " + str(end - start))
	
	start = Time.get_ticks_msec()
	for i in AMOUNT:
		r = Rect2i(i,i,i,i)
		r.position = Vector2i((r.position * recip).floor())
		r.end = Vector2i((r.end * recip).ceil())
	end = Time.get_ticks_msec()
	print("rect, floor + recip on pos and end individually (fastest): " + str(end - start))
	start = Time.get_ticks_msec()
	for i in AMOUNT:
		r = Rect2i(i,i,i,i)
		var rr := r
		rr.position = Vector2i((rr.position * recip).floor())
		rr.end = Vector2i((rr.end * recip).ceil())
	end = Time.get_ticks_msec()
	print("rect, floor + recip on pos and end individually. also new var: " + str(end - start))
	start = Time.get_ticks_msec()
	var rrr: Rect2i
	for i in AMOUNT:
		r = Rect2i(i,i,i,i)
		rrr = r
		rrr.position = Vector2i((rrr.position * recip).floor())
		rrr.end = Vector2i((rrr.end * recip).ceil())
	end = Time.get_ticks_msec()
	print("rect, floor + recip on pos and end individually. also new var but preallocated: " + str(end - start))
	var p: Vector2i
	start = Time.get_ticks_msec()
	for i in AMOUNT:
		r = Rect2i(i,i,i,i)
		p = Vector2i((r.position * recip).floor())
		Rect2i(
			p,
			 Vector2i((r.end * recip).ceil()) - p
		)
	end = Time.get_ticks_msec()
	print("rect, floor + recip on pos and end individually (construction): " + str(end - start))
	start = Time.get_ticks_msec()
	for i in AMOUNT:
		r = Rect2i(i,i,i,i)
		r.position.x = floori(r.position.x * recip)
		r.position.y = floori(r.position.y * recip)
		r.end.x = ceili(r.end.x * recip)
		r.end.y = ceili(r.end.y * recip)
	end = Time.get_ticks_msec()
	print("rect, floor + recip on pos and end individually by component: " + str(end - start))
	var aaaaa = Vector2i(_huge_mult, _huge_mult)
	var aaaaab = Vector2i(_huge_mult_factor, _huge_mult_factor)
	start = Time.get_ticks_msec()
	for i in AMOUNT:
		r = Rect2i(i,i,i,i)
		r.position = ((r.position + aaaaa) / tile_size) - aaaaab
		r.end = ((r.end - aaaaa) / tile_size) + aaaaab
	end = Time.get_ticks_msec()
	print("rect, manually for pos and end: " + str(end - start))
	start = Time.get_ticks_msec()
	for i in AMOUNT:
		r = Rect2i(i,i,i,i)
		_get_rect_tile_iter(r)
	end = Time.get_ticks_msec()
	print("function (the value of inlining!): " + str(end - start))
	
