@tool
extends Control

const FONT := preload("res://fonts/lock_count.png")
const CHAR_SIZE := Vector2i(10, 12)
const CHARSET := "0123456789iLx+="
## For each character, the pixels between it and the left side, and the pixels between it and the right side (useful for precise size calculations)
const CHARS_REACH := [
	[0, 2],
	[1, 5],
	[0, 3],
	[0, 3],
	[0, 2],
	[0, 3],
	[0, 3],
	[0, 3],
	[0, 2],
	[0, 3],
	[1, 7], # i
	[0, 2],
	[1, 1],
	[0, 0],
	[0, 0],
]
const L = 11
const I = 10

@export var text := "":
	set(val):
		text = val
		_update_size()
		queue_redraw()

@export_enum("Real", "Imaginary", "Don't show") var lock_type := 0:
	set(val):
		lock_type = val
		_update_size()
		queue_redraw()

func _update_size() -> void:
	if text == "":
		custom_minimum_size = Vector2i.ZERO
		size = Vector2i.ZERO
		return
	var text_size = Vector2i(CHAR_SIZE * Vector2i(text.length(), 1))
	text_size.y -= 1
	var isize = Vector2i(size)
	match lock_type:
		0: # real
			text_size.x += 11
			text_size.y += 1 # lock is big
			# remove right space
			text_size.x -= CHARS_REACH[CHARSET.find(text[text.length()-1])][1]
		1: # imaginary
			text_size.x += 3
			# remove left space
			text_size.x -= CHARS_REACH[CHARSET.find(text[0])][0]
		2: # don't show
			# remove left and right space
			text_size.x -= CHARS_REACH[CHARSET.find(text[0])][0]
			text_size.x -= CHARS_REACH[CHARSET.find(text[text.length()-1])][1]
	custom_minimum_size = text_size
	size = text_size

func _draw() -> void:
	if text == "":
		return
	
	var offset := Vector2i.ZERO
	match lock_type:
		0: # real
			draw_texture_rect_region(FONT,
				Rect2(offset, CHAR_SIZE),
				Rect2(Vector2(CHAR_SIZE.x * L, 0), CHAR_SIZE)
			)
			offset.x += 11
		1: # imaginary
			offset.x -= CHARS_REACH[CHARSET.find(text[0])][0]
			draw_texture_rect_region(FONT,
				Rect2(offset + Vector2i(text.length() * CHAR_SIZE.x,0), CHAR_SIZE),
				Rect2(Vector2(CHAR_SIZE.x * I, 0), CHAR_SIZE)
			)
		2: # don't show
			offset.x -= CHARS_REACH[CHARSET.find(text[0])][0]
	var pos := Vector2i(0, 0)
	for c in text:
		var i := CHARSET.find(c)
		if i != -1:
			draw_texture_rect_region(FONT,
				Rect2(pos + offset, CHAR_SIZE),
				Rect2(Vector2(CHAR_SIZE.x * i, 0), CHAR_SIZE)
			)
		pos.x += CHAR_SIZE.x
