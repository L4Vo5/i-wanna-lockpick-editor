@tool
extends Node2D
class_name OutlineText

@export_multiline var text: String = "":
	set(val):
		text = val
		queue_redraw()

@export var font: Font = null:
	set(val):
		font = val
		queue_redraw()

@export var center_color: Color = Color.WHITE:
	set(val):
		center_color = val
		queue_redraw()

@export var outline_color: Color = Color.BLACK:
	set(val):
		outline_color = val
		queue_redraw()

@export var outline_corners: bool = false:
	set(val):
		outline_corners = val
		queue_redraw()

@export var outline_distance: int = 1:
	set(val):
		outline_distance = val
		queue_redraw()

@export var font_size: int = 16:
	set(val):
		font_size = val
		queue_redraw()

@export var line_sep := 10:
	set(val):
		line_sep = val
		queue_redraw()

@export var center_horizontally: bool = true:
	set(val):
		center_horizontally = val
		queue_redraw()

@export var center_vertically: bool = false:
	set(val):
		center_vertically = val
		queue_redraw()

func _draw() -> void:
	var f := font
	#if !f:
		#f = get_theme_font("")
	if !f:
		push_error("Can't draw text. No font.")
		return
	var lines := text.split("\n")
	if lines[lines.size() - 1] == "":
		lines.remove_at(lines.size() - 1)
	var yoffset := 0
	if center_vertically:
		yoffset = -lines.size() * line_sep / 2
	for xx in 3:
		for yy in 3:
			var x := (xx + 2) % 3 - 1
			var y := (yy + 2) % 3 - 1
			if not outline_corners and abs(x) + abs(y) == 2: continue
			#print("x: %d, y: %d" % [x, y])
			var col := center_color if x == 0 and y == 0 else outline_color
			#draw_multiline_string(f, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, -1, col)
			# WAITING4GODOT: HORIZONTAL_ALIGNMENT_CENTER doesn't work, so I have to do this..
			x *= outline_distance
			y *= outline_distance
			y += yoffset
			for line in lines:
				var pos := Vector2(x, y)
				if center_horizontally:
					var s := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP, font_size)
					pos.x -= s.x / 2
				draw_string(f, pos, line, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP, font_size, col)
				y += line_sep
