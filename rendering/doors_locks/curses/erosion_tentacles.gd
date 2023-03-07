@tool
extends Control

func _ready() -> void:
	resized.connect(regen_tentacles)
	regen_tentacles()

const HEIGHTS := [9, 3, 7, 3]

# The algorithm for placing tentacles is a bit shitty, so it'll look bad on strange sizes... could fix in the future?
# TODO: ^
func regen_tentacles() -> void:
	for child in get_children():
		child.queue_free()
	
	# top border with bottom tentacle texture
	var top_border := TextureRect.new()
	top_border.texture = preload("res://rendering/doors_locks/curses/spr_erosion_tentacle_bottom.png")
	top_border.stretch_mode = TextureRect.STRETCH_TILE
	top_border.size = Vector2i(size.x - 2, 2)
	top_border.position = Vector2i(1, 1)
	add_child(top_border)
	
	# approx. one tentacle every 15.5 pixels (average of heights + 10)
	var amount := roundi(int(size.y - 2) / 15.5)
	# the size this amount corresponds to
	var acting_size := amount * 15.5
	# we're gonna adjust the positions to stretch the tentacles over the actual size
	var diff_size = (size.y - 2) / acting_size
	
	var y = 0
	for i in amount:
		var height = HEIGHTS[i % HEIGHTS.size()]
		create_tentacle(3 + int(y * diff_size), height)
		y += height + 10

func create_tentacle(y: int, height: int) -> void:
	var top := TextureRect.new()
	top.texture = preload("res://rendering/doors_locks/curses/spr_erosion_tentacle_top.png")
	top.stretch_mode = TextureRect.STRETCH_TILE
	top.size = Vector2i(size.x - 2, 2)
	top.position = Vector2i(1, y+1)
	
	var middle := ColorRect.new()
	middle.modulate = Color(0.282353, 0.0509804, 0.0509804, 0.705882)
	middle.size = Vector2i(size.x - 2, height)
	middle.position = Vector2i(1, y+1+2)
	
	var bottom := TextureRect.new()
	bottom.texture = preload("res://rendering/doors_locks/curses/spr_erosion_tentacle_bottom.png")
	bottom.stretch_mode = TextureRect.STRETCH_TILE
	bottom.size = Vector2i(size.x - 2, 2)
	bottom.position = Vector2i(1, y + 1 + 2 + height)
	
	add_child(top)
	add_child(middle)
	add_child(bottom)
