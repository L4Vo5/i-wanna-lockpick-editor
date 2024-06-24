extends Control
# Had to make this to ensure the image doesn't get drawn on fractional coordinates...
var texture: Texture2D:
	set(val):
		if is_instance_valid(texture):
			texture.changed.disconnect(update)
		texture = val
		if is_instance_valid(texture):
			texture.changed.connect(update)
		update()

func update() -> void:
	if is_instance_valid(texture):
		custom_minimum_size = texture.get_size()
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(texture): return
	# center it
	var desired_pos := (size - texture.get_size()) / 2
	# integer
	desired_pos = desired_pos.floor()
	
	draw_texture_rect(texture, Rect2(desired_pos, texture.get_size()), false)
