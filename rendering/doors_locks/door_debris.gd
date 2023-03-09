extends Node2D

var velocity := Vector2.ZERO
var gravity := 0.0
func _ready() -> void:
	velocity.y = randf_range(-4, -3)
	velocity.x = randf_range(-1.2, 1.2)
	gravity = randf_range(0.4, 0.5)

func _physics_process(delta: float) -> void:
	position += velocity
	velocity.y += gravity
	modulate.a -= 0.04
	if modulate.a <= 0.00:
		queue_free()


