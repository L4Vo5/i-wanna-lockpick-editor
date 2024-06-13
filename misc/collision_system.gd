@tool
extends EditorScript
class_name CollisionSystem
## Collision system, implemented manually, unfortunately.
##
## Hopefully it'll be fast enough, otherwise I can try getting fancy with the algorithms (particularly for big objects). As a last resort, I could always reimplement it in GDExtension. That'll complicate the build process, though.
##
## IMPORTANT: Please don't access any of the variables starting with _

## Size of each tile in the grid. This limits how granular the system is!
var tile_size := 16:
	set(val):
		assert(false, "Changing grid tile size is currently unsupported.")
const I32_MAX := Vector2i.MAX.x
var _huge_mult := snappedi(I32_MAX/2, tile_size)
var _huge_mult_factor := _huge_mult / tile_size
var cool_vec := Vector4i(_huge_mult, _huge_mult, -_huge_mult, -_huge_mult)
var cool_vec_2 := Vector4i(_huge_mult_factor, _huge_mult_factor, -_huge_mult_factor, -_huge_mult_factor)

# For each tile (Vector2i), what rects (int) are inside it.
# Tiles are stored based on tile_size. So (2, 4) will correspond to the tile whose upper left corner is (32, 64).
var _tile_to_rects := {}
# For each rect (int), what tiles it's in.
var _rect_id_to_tiles := {}
# For each rect id (int), the Rect2i it represents.
# This could be useful in the future, but currently it isn't.
var _rects := {}

var _next_rect_id := 1
## Adds a rect to the system.
## Returns the unique id given to that rect.
func add_rect(rect: Rect2i) -> int:
	_rects[_next_rect_id] = rect
	_next_rect_id += 1
	return _next_rect_id - 1

## Removes the rect with the given id from the system.
func remove_rect(id: int) -> void:
	pass

## Returns true if the given rect has a collision with another rect in the system.
func rect_has_collision(rect: Rect2i) -> bool:
	return false

# Gets the tile coordinates that compose a rect.
# That is, every tile that the rect is even a little bit inside. NOT counting edges. So with tile_size = 16, Rect2i(64, 0, 16, 16) won't be in 9 different tiles, only in (4, 0)
func rect_get_coords(rect: Rect2i) -> Vector4i:
	# TL = rect.position
	# BR = rect.position + rect.size
	# Turn them to tile coordinates. TL will want division to be rounded towards -infinity, while BR will want it towards +infinity. (floor and ceil work differently on negative values)
	# Default division is towards -inf for positive numbers. So we can just leverage it by offsetting numbers by roughtly INT32_MAX/2. Conversely, we can get +inf by offsetting them by roughly -INT32_MAX/2. (As long as those offset numbers are multiples of tile_size)
	return (Vector4i(
		rect.position.x,
		rect.position.y,
		rect.size.x + rect.position.x,
		rect.size.y+rect.position.y
	) + cool_vec) / _huge_mult - cool_vec_2

func temp(a: int) -> void:
	print(str(a) + "...")
	print((a + _huge_mult) / tile_size - _huge_mult_factor)
	print((a - _huge_mult) / tile_size + _huge_mult_factor)
	a = -a
	print(str(a) + "...")
	print((a + _huge_mult) / tile_size - _huge_mult_factor)
	print((a - _huge_mult) / tile_size + _huge_mult_factor)

func _run() -> void:
	var start := Time.get_ticks_msec()
	var end := Time.get_ticks_msec()
	var rect := Rect2i(99, 43, 17, 88)
	const AMOUNT = 2_000_000
	start = Time.get_ticks_msec()
	for i in AMOUNT:
		pass
	end = Time.get_ticks_msec()
	
	print("Baseline: " + str(end - start))

	start = Time.get_ticks_msec()
	for i in AMOUNT:
		(Vector4i(
		rect.position.x,
		rect.position.y,
		rect.size.x + rect.position.x,
		rect.size.y+rect.position.y
	) + cool_vec)
	end = Time.get_ticks_msec()
	print("Vec: " + str(end - start))
	start = Time.get_ticks_msec()
	for i in AMOUNT:
		var v := (Vector4i(
		rect.position.x,
		rect.position.y,
		rect.size.x + rect.position.x,
		rect.size.y+rect.position.y
	) + cool_vec)
	end = Time.get_ticks_msec()
	print("Vec 2: " + str(end - start))
	for i in AMOUNT:
		(Vector4i(
		rect.position.x,
		rect.position.y,
		rect.size.x + rect.position.x,
		rect.size.y+rect.position.y
	) + cool_vec) / tile_size - cool_vec_2
	end = Time.get_ticks_msec()
	print("Method 1 (this is the fastest): " + str(end - start))
	start = Time.get_ticks_msec()
	for i in AMOUNT:
		(Vector4i(
		(rect.position.x + _huge_mult) / tile_size-_huge_mult_factor,
		(rect.position.y + _huge_mult) / tile_size-_huge_mult_factor,
		(rect.size.x + rect.position.x - _huge_mult)/tile_size+_huge_mult_factor,
		(rect.size.y+rect.position.y-_huge_mult)/tile_size+_huge_mult_factor
	) + cool_vec)
	end = Time.get_ticks_msec()
	print("Method 2: " + str(end - start))
	start = Time.get_ticks_msec()
	for i in AMOUNT:
		rect_get_coords(rect)
	end = Time.get_ticks_msec()
	print("Func: " + str(end - start))
