@tool
extends Control
class_name LockCountDraw

const FONT := preload("res://fonts/lock_count.png")
const CHAR_SIZE := Vector2i(10, 12)
const CHARSET := "0123456789iLx+="
## For each character, the pixels between it and the left side, and the pixels between it and the right side (useful for precise size calculations)
const CHARS_REACH: Array[Array] = [
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
	[1, 7], # "i"
	[0, 2],
	[1, 1],
	[0, 0],
	[0, 0],
]
const L = 11
const I = 10

@export var text := "":
	set(val):
		if text == val: return
		text = val
		_update_size()
		queue_redraw()

@export_enum("Real", "Imaginary", "Don't show") var lock_type := 0:
	set(val):
		lock_type = val
		_update_size()
		queue_redraw()

# WAITING4GODOT: static funcs...
@warning_ignore("shadowed_variable")
static func get_min_size(text: String, lock_type: int) -> Vector2i:
	if text == "":
		return Vector2i.ZERO
	var text_size := Vector2i(CHAR_SIZE * Vector2i(text.length(), 1))
	text_size.y -= 1
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
	return text_size

func _update_size() -> void:
	var s := get_min_size(text, lock_type)
	size = s
	custom_minimum_size = s
	draw_text(get_canvas_item(), text, lock_type)

# WAITING4GODOT: static funcs...
@warning_ignore("shadowed_variable")
static func draw_text(rid: RID, text: String, lock_type: int) -> void:
	if text == "":
		return
	RenderingServer.canvas_item_clear(rid)
	assert(PerfManager.start("LockCountDraw::draw_text"))
	var offset := Vector2i.ZERO
	match lock_type:
		0: # real
			RenderingServer.canvas_item_add_texture_rect_region(rid,
				Rect2(offset, CHAR_SIZE),
				FONT,
				Rect2(Vector2(CHAR_SIZE.x * L, 0), CHAR_SIZE)
			)
			offset.x += 11
		1: # imaginary
			offset.x -= CHARS_REACH[CHARSET.find(text[0])][0]
			RenderingServer.canvas_item_add_texture_rect_region(rid,
				Rect2(offset + Vector2i(text.length() * CHAR_SIZE.x,0), CHAR_SIZE),
				FONT,
				Rect2(Vector2(CHAR_SIZE.x * I, 0), CHAR_SIZE)
			)
		2: # don't show
			offset.x -= CHARS_REACH[CHARSET.find(text[0])][0]
	var pos := Vector2i(0, 0)
	var i := 0
	for c in text:
		i = CHARSET.find(c)
		if i != -1:
			RenderingServer.canvas_item_add_texture_rect_region(rid,
				Rect2(pos + offset, CHAR_SIZE),
				FONT,
				Rect2(Vector2(CHAR_SIZE.x * i, 0), CHAR_SIZE)
			)
		pos.x += CHAR_SIZE.x
	assert(PerfManager.end("LockCountDraw::draw_text"))
	return

func _draw() -> void:
	draw_text(get_canvas_item(), text, lock_type)
