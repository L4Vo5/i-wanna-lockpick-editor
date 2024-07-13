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
	for x in range(rect.position.x, rect.end.x):
		_add_line(left_lines, Vector2i(x, rect.position.y), sign)
		_add_line(right_lines, Vector2i(x, rect.end.y), sign)
	for y in range(rect.position.y, rect.end.y):
		_add_line(top_lines, Vector2i(rect.position.x, y), sign)
		_add_line(bottom_lines, Vector2i(rect.end.x, y), sign)

func add_rectangle_no_grid(rect: Rect2i, sign: int) -> void:
	var outer := Rect2i()
	outer.position = Vector2i((rect.position / (resolution as float)).floor())
	outer.end = Vector2i((rect.end / (resolution as float)).ceil())
	add_rectangle(outer, sign)

func _draw() -> void:
	var diag_offset := Vector2(-1, -1) * (width / 2)
	for pos in left_lines:
		if right_lines.has(pos):
			continue
		var corner := Vector2(pos * resolution) + diag_offset
		draw_rect(Rect2(corner, Vector2(resolution + width, width)), color)
	for pos in right_lines:
		if left_lines.has(pos):
			continue
		var corner := Vector2(pos * resolution) + diag_offset
		draw_rect(Rect2(corner, Vector2(resolution + width, width)), color)
	for pos in top_lines:
		if bottom_lines.has(pos):
			continue
		var corner := Vector2(pos * resolution) + diag_offset
		draw_rect(Rect2(corner, Vector2(width, resolution + width)), color)
	for pos in bottom_lines:
		if top_lines.has(pos):
			continue
		var corner := Vector2(pos * resolution) + diag_offset
		draw_rect(Rect2(corner, Vector2(width, resolution + width)), color)
