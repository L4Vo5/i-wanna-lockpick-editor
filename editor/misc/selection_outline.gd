extends Node2D
class_name SelectionOutline

var tiles := {}
var outline_tiles := {}

@export var tile_size: int = 16
@export var color: Color = Color.WHITE:
	set(value):
		if color == value: return
		color = value
		modulate = value
@export var width: float = 3:
	set(val):
		if width == val: return
		width = val
		queue_redraw()

func clear() -> void:
	tiles = {}
	outline_tiles = {}
	position = Vector2i.ZERO
	queue_redraw()

## Mimick another SelectionOutline's rects (until either is cleared)
## Much more performant if both are showing the same thing, as preprorcessing is the most expensive part. 
func mimic_other(other: SelectionOutline) -> void:
	tiles = other.tiles
	outline_tiles = other.outline_tiles
	queue_redraw()

func add_rect(rect: Rect2i) -> void:
	var tile_iter := CollisionSystem.get_rect_tile_iter(rect, 1.0 / tile_size)
	for y in range(tile_iter.position.y, tile_iter.end.y):
		for x in range(tile_iter.position.x, tile_iter.end.x):
			var coord := Vector2i(x, y)
			tiles[coord] = true
			outline_tiles.erase(coord)
	
	var outline_iter := tile_iter.grow(1)
	for x in range(outline_iter.position.x, outline_iter.end.x):
		var top := Vector2i(x, outline_iter.position.y)
		var bottom := Vector2i(x, outline_iter.end.y - 1)
		if not tiles.has(top):
			var num: int = outline_tiles.get(top, 0)
			if x < outline_iter.end.x - 2:
				num |= Bytes.DR
			if x >= outline_iter.position.x + 2:
				num |= Bytes.DL
			if x > outline_iter.position.x and x < outline_iter.end.x - 1:
				num |= Bytes.D
			outline_tiles[top] = num
		if not tiles.has(bottom):
			var num: int = outline_tiles.get(bottom, 0)
			if x < outline_iter.end.x - 2:
				num |= Bytes.UR
			if x >= outline_iter.position.x + 2:
				num |= Bytes.UL
			if x > outline_iter.position.x and x < outline_iter.end.x - 1:
				num |= Bytes.U
			outline_tiles[bottom] = num
	for y in range(outline_iter.position.y + 1, outline_iter.end.y - 1):
		var left := Vector2i(outline_iter.position.x, y)
		var right := Vector2i(outline_iter.end.x - 1, y)
		if not tiles.has(left):
			var num: int = outline_tiles.get(left, 0)
			if y < outline_iter.end.y - 2:
				num |= Bytes.DR
			if y >= outline_iter.position.y + 2:
				num |= Bytes.UR
			if y > outline_iter.position.y and y < outline_iter.end.y - 1:
				num |= Bytes.R
			outline_tiles[left] = num
		if not tiles.has(right):
			var num: int = outline_tiles.get(right, 0)
			if y < outline_iter.end.y - 2:
				num |= Bytes.DL
			if y >= outline_iter.position.y + 2:
				num |= Bytes.UL
			if y > outline_iter.position.y and y < outline_iter.end.y - 1:
				num |= Bytes.L
			outline_tiles[right] = num
	queue_redraw()

func remove_rect(rect: Rect2i) -> void:
	assert(false, "Unimplemented!")
	pass

var cached_rects := {}
enum {
#   1,  2, 4,  8, 16, 32, 64, 128
	UL, U, UR, R, DR, D,  DL, L
}
enum Bytes {
	UL = 1, U = 2, UR = 4, R = 8, DR = 16, D = 32, DL = 64, L = 128
}
const lookup_sides := [
	Vector2i.UP + Vector2i.LEFT,
	Vector2i.UP,
	Vector2i.UP + Vector2i.RIGHT,
	Vector2i.RIGHT,
	Vector2i.DOWN + Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.DOWN + Vector2i.LEFT,
	Vector2i.LEFT,
]
func get_rects() -> Array:
	var rects = cached_rects.get([width, tile_size], [])
	if not rects.is_empty():
		return rects
	assert(PerfManager.start(&"SelectionOutline::get_rects"))
	rects = []
	rects.resize(256)
	
	var sides := [false, false, false, false, false, false, false, false]
	for i in 256:
		var base_rects : Array[Rect2] = [
			Rect2(0, 0, 0, 0).grow_individual(0, 0, width, width),
			Rect2(0, 0, tile_size, 0).grow_individual(0, 0, 0, width),
			Rect2(tile_size, 0, 0, 0).grow_individual(width, 0, 0, width),
			Rect2(tile_size, 0, 0, tile_size).grow_individual(width, 0, 0, 0),
			Rect2(tile_size, tile_size, 0, 0).grow_individual(width, width, 0, 0),
			Rect2(0, tile_size, tile_size, 0).grow_individual(0, width, 0, 0),
			Rect2(0, tile_size, 0, 0).grow_individual(0, width, width, 0),
			Rect2(0, 0, 0, tile_size).grow_individual(0, 0, width, 0),
		]
		var j := i
		var r := []
		for side in 8:
			sides[side] = j & 1 == 1
			j >>= 1
		if sides[U]:
			sides[UR] = false
			sides[UL] = false
		if sides[D]:
			sides[DR] = false
			sides[DL] = false
		if sides[L]:
			sides[DL] = false
			sides[UL] = false
		if sides[R]:
			sides[DR] = false
			sides[UR] = false
		if sides[U]:
			base_rects[L] = base_rects[L].grow_individual(0, -width, 0, 0)
			base_rects[R] = base_rects[R].grow_individual(0, -width, 0, 0)
		if sides[D]:
			base_rects[L] = base_rects[L].grow_individual(0, 0, 0, -width)
			base_rects[R] = base_rects[R].grow_individual(0, 0, 0, -width)
		for side in 8:
			if sides[side]:
				r.push_back(base_rects[side])
		rects[i] = r
	cached_rects[[width, tile_size]] = rects
	assert(PerfManager.end(&"SelectionOutline::get_rects"))
	return rects

func _draw() -> void:
	assert(PerfManager.start(&"SelectionOutline::draw"))
	var rects := get_rects()
	
	for tile in outline_tiles:
		var tile_pos := tile as Vector2 * tile_size
		var bytes: int = outline_tiles[tile]
		assert(bytes != 0)
		for rect in rects[bytes]:
			rect.position += tile_pos
			draw_rect(rect, Color.WHITE)
	
	assert(PerfManager.end(&"SelectionOutline::draw"))
