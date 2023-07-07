extends Control
# Had to make this to ensure the image doesn't get drawn on fractional coordinates...
var texture: Texture2D:
	set(val):
		if is_instance_valid(texture):
			texture.changed.disconnect(update)
		texture = val
		texture.changed.connect(update)
		update()

func update() -> void:
	queue_redraw()
	custom_minimum_size = texture.get_size()

func _draw() -> void:
	# make sure global position isn't fractional
	assert(global_position == Vector2(Vector2i(global_position)))
	# center it
	var desired_pos := (size - texture.get_size()) / 2
	# integer
	desired_pos = desired_pos.floor()
	
	draw_texture_rect(texture, Rect2(desired_pos, texture.get_size()), false)
