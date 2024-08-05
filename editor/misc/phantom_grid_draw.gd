@tool
extends Node2D
class_name PhantomGridDraw

var grid_size := Vector2(32, 32):
	set(val):
		if grid_size == val: return
		grid_size = val
		queue_redraw()

var amount := 3:
	set(val):
		if amount == val: return
		amount = val
		queue_redraw()

func get_rect() -> Rect2:
	return Rect2(grid_size * (-amount) + position, grid_size * (amount*2+1))

func _draw() -> void:
	var width := 2
	for x in range(-amount, amount+1):
		for y in range(-amount, amount+1):
			draw_rect(Rect2(grid_size * Vector2(x, y), grid_size), Color.WHITE, false, width)

