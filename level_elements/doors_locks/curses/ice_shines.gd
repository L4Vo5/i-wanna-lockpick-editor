@tool
extends Control

@onready var internal := $Internal

func _ready() -> void:
	resized.connect(regen_shines)
	regen_shines()


func regen_shines() -> void:
	internal.size = size - Vector2(2,2)
	for child in internal.get_children():
		child.queue_free()
	if false:
		pass
#	elif size == Vector2(96, 64):
#		add_shine(7, 10)
#		add_shine(21, 14)
#		add_shine(5, 3, true)
#		add_shine(9, 5, true)
#		add_shine(20, 5, true)
#	elif size == Vector2(64, 64):
#		add_shine(7, 10)
#		add_shine(21, 14)
#		add_shine(5, 3, true)
#		add_shine(9, 5, true)
#		add_shine(20, 5, true)
#	elif size == Vector2(32, 64):
#		add_shine(7, 10)
#		add_shine(20, 5, true)
#		add_shine(6, 3, true)
#		add_shine(10, 5, true)
#	elif size == Vector2(32, 32):
#		add_shine(7, 10)
#		add_shine(5, 3, true)
#		add_shine(9, 4, true)
	else:
		# meh lmao
		var mult = 1
		var mult2 = 1
		if size.x + size.y > 115:
			var extra = size.x + size.y - 115
			mult = 1 + extra / 115
			mult2 = sqrt(mult)
		if size.x + size.y > 30:
			add_shine(5 * mult, 3 * mult2, true)
		if size.x + size.y > 40:
			add_shine(7 * mult, 10 * mult2)
		if size.x + size.y > 55:
			add_shine(9 * mult, 5 * mult2, true)
		if size.x + size.y > 80:
			add_shine(20 * mult, 5 * mult2, true)
		if size.x + size.y > 115:
			add_shine(21 * mult, 14 * mult2)
		
		
		

## distance: diagonal distance from corner
##
## width: pixel width
func add_shine(distance: int, width: int, bottom_right := false) -> void:
	var shine := ColorRect.new()
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shine.rotation_degrees = -45
	shine.position.y = distance * 2 + 2
	shine.size.y = width / sqrt(2)
	shine.size.x = shine.position.y * sqrt(2) + (shine.size.y - 1) * 2
	shine.position = shine.position + Vector2(-(shine.size.y - 1), 0).rotated(deg_to_rad(-45))
	if bottom_right:
		shine.position = size - shine.position
		shine.rotation_degrees += 180
	shine.position -= Vector2(1,1)
	internal.add_child(shine)
