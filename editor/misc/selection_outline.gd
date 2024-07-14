@tool
extends Node2D
class_name SelectionOutline

## dict of Vector2i which represent the top position of vertical lines
@export var left_lines: Dictionary

## dict of Vector2i which represent the top position of vertical lines
@export var right_lines: Dictionary

## dict of Vector2i which represent the left position of horizontal lines
@export var top_lines: Dictionary

## dict of Vector2i which represent the left position of horizontal lines
@export var bottom_lines: Dictionary

@export var resolution: int = 16
@export var color: Color = Color.WHITE:
	set(value):
		if color == value: return
		color = value
		queue_redraw()
@export var width: float = 3

func reset() -> void:
	left_lines.clear()
	right_lines.clear()
	top_lines.clear()
	bottom_lines.clear()
	position = Vector2i.ZERO
	queue_redraw()

static func _add_line(dict: Dictionary, pos: Vector2i, sign: int) -> void:
	if sign == 1 and not dict.has(pos):
		dict[pos] = 1
	else:
		dict[pos] += sign
		if sign == -1 and dict[pos] == 0:
			dict.erase(pos)

func add_rectangle(rect: Rect2i, sign: int) -> void:
	rect.position -= Vector2i(position) / resolution
	for y in range(rect.position.y, rect.end.y):
		_add_line(left_lines, Vector2i(rect.position.x, y), sign)
		_add_line(right_lines, Vector2i(rect.end.x, y), sign)
	for x in range(rect.position.x, rect.end.x):
		_add_line(top_lines, Vector2i(x, rect.position.y), sign)
		_add_line(bottom_lines, Vector2i(x, rect.end.y), sign)

func add_rectangle_no_grid(rect: Rect2i, sign: int) -> void:
	var outer := Rect2i()
	outer.position = Vector2i((rect.position / (resolution as float)).floor())
	outer.end = Vector2i((rect.end / (resolution as float)).ceil())
	add_rectangle(outer, sign)

func _draw() -> void:
	#var diag_offset := Vector2(-1, -1) * (width / 2)
	var offset := Vector2.UP * width
	var size := Vector2(resolution, width)
	for pos in top_lines:
		if bottom_lines.has(pos):
			continue
		var corner := Vector2(pos * resolution) + offset
		var rect := Rect2(corner, size)
		if not right_lines.has(pos) and not right_lines.has(pos + Vector2i.UP):
			rect = rect.grow_side(SIDE_LEFT, width)
		if not left_lines.has(pos + Vector2i.RIGHT) and not left_lines.has(pos + Vector2i(1, -1)):
			rect = rect.grow_side(SIDE_RIGHT, width)
		draw_rect(rect, color)
	for pos in bottom_lines:
		if top_lines.has(pos):
			continue
		var corner := Vector2(pos * resolution)
		var rect := Rect2(corner, size)
		if not right_lines.has(pos) and not right_lines.has(pos + Vector2i.UP):
			rect = rect.grow_side(SIDE_LEFT, width)
		if not left_lines.has(pos + Vector2i.RIGHT) and not left_lines.has(pos + Vector2i(1, -1)):
			rect = rect.grow_side(SIDE_RIGHT, width)
		draw_rect(rect, color)
	size = Vector2(width, resolution)
	offset = Vector2.LEFT * width
	for pos in left_lines:
		if right_lines.has(pos):
			continue
		var corner := Vector2(pos * resolution) + offset
		var rect := Rect2(corner, size)
		if not bottom_lines.has(pos) and not bottom_lines.has(pos + Vector2i.LEFT):
			rect = rect.grow_side(SIDE_TOP, width)
		if not top_lines.has(pos + Vector2i.DOWN) and not top_lines.has(pos + Vector2i(-1, 1)):
			rect = rect.grow_side(SIDE_BOTTOM, width)
		draw_rect(rect, color)
	for pos in right_lines:
		if left_lines.has(pos):
			continue
		var corner := Vector2(pos * resolution)
		var rect := Rect2(corner, size)
		if not bottom_lines.has(pos) and not bottom_lines.has(pos + Vector2i.LEFT):
			rect = rect.grow_side(SIDE_TOP, width)
		if not top_lines.has(pos + Vector2i.DOWN) and not top_lines.has(pos + Vector2i(-1, 1)):
			rect = rect.grow_side(SIDE_BOTTOM, width)
		draw_rect(rect, color)
