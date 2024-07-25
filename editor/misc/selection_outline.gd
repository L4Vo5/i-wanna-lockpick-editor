@tool
extends Node2D
class_name SelectionOutline

var tiles := {}

@export var resolution: int = 16
@export var color: Color = Color.WHITE:
	set(value):
		if color == value: return
		color = value
		queue_redraw()
@export var width: float = 3:
	set(val):
		if width == val: return
		width = val
		queue_redraw()

func reset() -> void:
	tiles.clear()
	position = Vector2i.ZERO
	queue_redraw()

func add_rectangle(rect: Rect2i, sign: int) -> void:
	rect.position -= Vector2i(position) / resolution
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var entry := Vector2(x, y) * resolution
			if tiles.has(entry):
				tiles[entry] += sign
				if tiles[entry] <= 0:
					tiles.erase(entry)
			else:
				tiles[entry] = 1

func _draw() -> void:
	assert(PerfManager.start("SelectionOutline::draw"))
	
	# organized by [check, offset, size]
	var data: PackedVector2Array = [
		Vector2.LEFT * resolution, Vector2(-width, 0), Vector2(width, resolution),
		Vector2.RIGHT * resolution, Vector2(resolution, 0), Vector2(width, resolution),
		Vector2.UP * resolution, Vector2(0, -width), Vector2(resolution, width),
		Vector2.DOWN * resolution, Vector2(0, resolution), Vector2(resolution, width),
		Vector2(-1, -1) * resolution, Vector2(-width, -width), Vector2(width, width),
		Vector2(1, -1) * resolution, Vector2(resolution, -width), Vector2(width, width),
		Vector2(1, 1) * resolution, Vector2(resolution, resolution), Vector2(width, width),
		Vector2(-1, 1) * resolution, Vector2(-width, resolution), Vector2(width, width),
	]
	
	for tile in tiles:
		for i in range(0, 24, 3):
			if not tiles.has(tile + data[i]):
				draw_rect(Rect2(tile + data[i+1], data[i+2]), color)
	assert(PerfManager.end("SelectionOutline::draw"))
