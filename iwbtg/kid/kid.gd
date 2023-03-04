@tool
extends CharacterBody2D
class_name Kid

@onready var sprite := %AnimatedSprite2D as AnimatedSprite2D
@onready var snd_jump := %Jump as AudioStreamPlayer
@onready var snd_jump_2 := %Jump2 as AudioStreamPlayer
const gravity := 0.4

var universe = 1

func _physics_process(delta: float) -> void:
	if Global.in_editor: return
	on_floor = test_move(transform, Vector2(0, gravity))
	on_ceiling = test_move(transform, Vector2(0, -1))
	run()
	fall_jump()
	anim()
	detect_doors()
	var current_speed := 3
	if on_floor and velocity.y == 0 and Input.is_action_pressed(&"fast"):
		current_speed = 6
	if Input.is_action_pressed(&"slow"):
		current_speed = 1
	move_and_collide(velocity * Vector2(current_speed, 0))
	move_and_collide(velocity * Vector2(0, 1))

var on_floor := false
var on_ceiling := false
var d_jumps := 1

func run() -> void:
	if Input.is_action_just_pressed(&"right"):
		velocity.x = 1
	elif Input.is_action_just_pressed(&"left"):
		velocity.x = -1
	elif Input.is_action_pressed(&"right") and not Input.is_action_pressed(&"left"):
		velocity.x = 1
	elif Input.is_action_pressed(&"left") and not Input.is_action_pressed(&"right"):
		velocity.x = -1
	elif not Input.is_action_pressed(&"left") and not Input.is_action_pressed(&"right"):
		velocity.x = 0
	if velocity.x > 0:
		sprite.flip_h = false
	elif velocity.x < 0:
		sprite.flip_h = true
	

func fall_jump() -> void:
	if on_floor:
		d_jumps = 1
		velocity.y = 0
		if Input.is_action_just_pressed(&"jump"):
			velocity.y = -8.5
			snd_jump.play()
	else:
		velocity.y += gravity
		if velocity.y > 9:
			velocity.y = 9
		if on_ceiling and velocity.y < 0:
			velocity.y = 0
		elif Input.is_action_just_pressed(&"jump") and d_jumps > 0:
			d_jumps -= 1
			velocity.y = -7
			snd_jump_2.play()
		elif Input.is_action_just_released(&"jump") and velocity.y < 0:
			velocity.y *= 0.45

func detect_doors() -> void:
	for info in [
		move_and_collide(velocity * Vector2(1,0), true), # horizontal movement
		move_and_collide(velocity * Vector2(0, 1), true) if velocity.y != 0 else move_and_collide(Vector2(0, 1), true) # vertical movement (check below if stopped)
	]:
		if info != null:
			var collider = info.get_collider()
			if collider.get_parent() is Door:
				interact_with_door(collider.get_parent())

func interact_with_door(door: Door) -> void:
	door.try_open()

func anim() -> void:
	if velocity.y < 0:
		sprite.play(&"jump")
	elif velocity.y > 0:
		sprite.play(&"fall")
	elif velocity.x == 0:
		sprite.play(&"idle")
	else:
		sprite.play(&"walk")
