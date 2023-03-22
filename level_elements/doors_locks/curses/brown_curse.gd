@tool
extends Control

const PART := preload("res://level_elements/doors_locks/curses/brown_particle.tscn")
var time = 119

func _physics_process(_delta: float) -> void:
	if !visible:
		time = 119
		return
	time += 1
	if time >= 120:
		time -= 120
		spawn_particles()

func spawn_particles() -> void:
	for child in get_children():
		child.queue_free()
	for x in size.x / 16:
		for y in size.y / 16:
			var part := PART.instantiate()
			part.position = position
			part.position.x += randf_range(4, 12) + 16 * x
			part.position.y += randf_range(4, 12) + 16 * y
			add_child(part)
	pass
