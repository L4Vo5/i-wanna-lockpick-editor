extends Control

const FONT := preload("res://fonts/lock_count.png")
const CHAR_SIZE := Vector2i(9, 12)
const CHARSET := "0123456789iL"
const L = 11
const I = 10

@export var text := "":
	set(val):
		text = val
		queue_redraw()

@export_enum("Real", "Imaginary", "Don't show") var lock_type := 0:
	set(val):
		lock_type = val
		queue_redraw()

func _draw() -> void:
	if text == "":
		return
	var offset := Vector2(
		(size.x - text.length() * CHAR_SIZE.x) / 2.0,
		(size.y - CHAR_SIZE.y) / 2.0) 
	match lock_type:
		0: # real
			offset.x += 5
			draw_texture_rect_region(FONT,
				Rect2(offset + Vector2(-11,0), CHAR_SIZE),
				Rect2(Vector2(CHAR_SIZE.x * L, 0), CHAR_SIZE)
			)
		1: # imaginary
			offset.x -= 3
			draw_texture_rect_region(FONT,
				Rect2(offset + Vector2(text.length() * CHAR_SIZE.x,0), CHAR_SIZE),
				Rect2(Vector2(CHAR_SIZE.x * I, 0), CHAR_SIZE)
			)
		2: # don't show
			pass
	var pos := Vector2(0, 0)
	var max := Vector2(0, 0)
	for char in text:
		var i := CHARSET.find(char)
		if i != -1:
			draw_texture_rect_region(FONT,
				Rect2(pos + offset, CHAR_SIZE),
				Rect2(Vector2(CHAR_SIZE.x * i, 0), CHAR_SIZE)
			)
		max.x = maxi(max.x, pos.x + CHAR_SIZE.x)
		pos.x += CHAR_SIZE.x
#	size = max
