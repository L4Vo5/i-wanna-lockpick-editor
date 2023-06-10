#@tool
extends Area2D
class_name LevelGoal

signal won
var has_won := false
var child_inside := false
var time := 0
var win_time := 0
var child_inside_time := 0
const PART := preload("res://level_elements/goal/goal_particle.tscn")
@onready var particles_parent: Node2D = $Particles
@onready var sprite: Sprite2D = $Sprite
@onready var snd_win: AudioStreamPlayer = $Win

func _ready() -> void:
	area_entered.connect(_on_body_entered)
	area_exited.connect(_on_body_exited)
	preprocess(58)

func _physics_process(_delta: float) -> void:
	# Should create particle on first step
	var step = 3 if child_inside else 6
	
	if child_inside:
		var time_since := time - child_inside_time
		time_since %= 120
		time_since += 1
		if time_since in [80, 100, 120]:
			for i in 20:
				var part := spawn_particle()
				part.velocity *= remap(time_since, 80, 120, 10, 20)
				part.velocity *= lerpf(0.95, 1.05, randf())
				part.hue = i * 360.0 / 20.0
				part.type = 1
	
	if time % step == 0:
		spawn_particle()
	sprite.position.y = (3 * sin(deg_to_rad(fmod(time + 2.5, 360))))
	time += 1

func win() -> void:
	if has_won: return
	Global.current_level.start_undo_action()
	Global.current_level.undo_redo.add_do_method(win)
	Global.current_level.undo_redo.add_undo_method(undo_win)
	Global.current_level.end_undo_action()
	
	snd_win.play()
	has_won = true
	win_time = time
	sprite.frame = 2
	won.emit()

func undo_win() -> void:
	has_won = false
	sprite.frame = 1
	
	for child in particles_parent.get_children():
		child.hue = 120

func spawn_particle(put_first := true) -> Node2D:
	# Spawn particle
	var part := PART.instantiate()
	if has_won:
		part.hue = 60
		if child_inside:
			part.set_meta(&"fast", true)
			part.velocity *= 10
	# TODO: This more effectively?
	particles_parent.add_child(part)
	if put_first:
		particles_parent.move_child(part, 0)
	return part

func _on_body_entered(_body: Node2D) -> void:
	win()
	child_inside = true
	child_inside_time = time + 60
	
	for child in particles_parent.get_children():
		if child.has_meta(&"fast"): continue
		child.set_meta(&"fast", true)
		child.velocity *= 10
		var new := PART.instantiate()
		new.set_meta(&"fast", true)
		new.velocity = child.velocity.rotated(deg_to_rad(randf() * 360))
		new._scale = child._scale
		new.hue = child.hue
		new.sat = child.sat
		new.mode = child.mode
		child.add_sibling(new)

func _on_body_exited(_body: Node2D) -> void:
	child_inside = false

func preprocess(amount: int) -> void:
	assert(PerfManager.start("Goal::preprocess (%d)" % amount))
	for i in amount:
		_physics_process(0)
		for part in particles_parent.get_children():
			part._physics_process(0)
	assert(PerfManager.end("Goal::preprocess (%d)" % amount))
