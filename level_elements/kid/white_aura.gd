extends Sprite2D

func _ready() -> void:
	hide()
	set_process(false)
	set_physics_process(false)

var angle := 0
func _physics_process(_delta: float) -> void:
	angle += 5
	var sin := sin(deg_to_rad(angle))
	var cos := cos(deg_to_rad(angle))
	modulate.a = cos
	scale = Vector2(sin, sin)
	if angle > 90:
		set_physics_process(false)
		hide()

func animate() -> void:
	show()
	set_physics_process(true)
	angle = 0
