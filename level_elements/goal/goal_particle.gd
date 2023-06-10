#@tool
extends Sprite2D

# this takes 58 frames to die
var mode := 0
var type := 0
var _scale := 0.1
var velocity := Vector2(0.1,0).rotated(deg_to_rad(randf() * 360.0))
# originally 85 (out of 360)
var hue := 120
var sat := 30
var time = 0
func _physics_process(_delta: float) -> void:
	# don't process if alone in editor (enable for tool mode)
#	if get_parent() is SubViewport: return
	if type == 1:
		velocity *= 0.95
	if mode == 0:
		_scale += ((1 - _scale) * 0.2)
		if _scale >= 0.98:
			mode = 1
			if type == 0:
				velocity *= 4
	else:
		_scale = _scale - 0.025
		if _scale <= 0:
			queue_free()
	sat = min((sat + 3), 255)
	modulate = Color.from_hsv((hue - (sat / 12)) / 360.0, sat / 255.0, 1)
	scale = Vector2.ONE * _scale / 2.5
	position += velocity
