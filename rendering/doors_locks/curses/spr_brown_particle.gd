@tool
extends Sprite2D

var part_scale := randf_range(0.2, 0.3)
var iaspd : int = [-4, 4][randi()%2]
var scaleA := 0.0
var speed := 0.1
var direction := randf() * 360

func _init() -> void:
	set_physics_process(true)
	scale = Vector2.ZERO
	position = Vector2.ZERO
	rotation = 0

func _physics_process(delta: float) -> void:
	scale += Vector2.ONE * (part_scale - scale.x) * 0.1
	rotation_degrees += iaspd
	speed = min(speed + 0.001, 0.4)
	scaleA += 1.25
	modulate.a = cos(deg_to_rad(scaleA))
	if scaleA >= 90:
		if Global.in_editor:
			set_physics_process(false)
		else:
			queue_free()
	position += Vector2(1,0).rotated(direction) * speed
