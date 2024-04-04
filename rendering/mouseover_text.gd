@tool
extends Node2D

const FONT := preload("res://fonts/fMouseover.fnt")
const COLOR_MAIN := Color.BLACK
const COLOR_SHADOW := Color8(192, 192, 192)

@export_multiline var text := "":
	set(val):
		# .fnt rendering won't accept the infinity symbol. I made it so the character ñ renders as infinity.
		text = val.replace("∞", "ñ")
		size = FONT.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		size += Vector2(16, 16)
		queue_redraw()

@export var chase_mouse := true
var size := Vector2.ZERO

func _process(_delta: float) -> void:
	if chase_mouse and not Global.in_editor:
		global_position = get_global_mouse_position()
		clamp_to_viewport_boundaries()

func clamp_to_viewport_boundaries() -> void:
	var r := get_viewport_rect()
	if position.x + size.x > r.position.x + r.size.x:
		position.x = r.position.x + r.size.x - size.x
	if position.y + size.y > r.position.y + r.size.y:
		position.y = r.position.y + r.size.y - size.y

const HALF := Vector2(0.5, 0.5)
func _draw() -> void:
	var pos := Vector2(8,24)
	draw_rect(Rect2(HALF, size), Color.WHITE, true)
	draw_rect(Rect2(HALF + Vector2(1,1), size - Vector2(1,1)), COLOR_SHADOW, false, 1)
	draw_rect(Rect2(HALF, size), Color.BLACK, false, 1)
	
	var offsets := [Vector2(1,1), Vector2(1,0), Vector2(0,1), Vector2.ZERO]
	var colors := [COLOR_SHADOW, COLOR_SHADOW, COLOR_SHADOW, COLOR_MAIN]
	for i in 4:
		draw_multiline_string(FONT, pos + offsets[i], text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, -1, colors[i])
