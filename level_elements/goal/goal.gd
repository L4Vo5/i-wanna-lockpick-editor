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
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
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
				part.hue = i * 360.0 / 20.0
				part.type = 1
	
	if time % step == 0:
		spawn_particle()
	sprite.position.y = (3 * sin(deg_to_rad(fmod(time + 2.5, 360))))
	time += 1

func win() -> void:
	if has_won: return
	snd_win.play()
	has_won = true
	win_time = time
	sprite.frame = 2
	won.emit()

func spawn_particle() -> Node2D:
	# Spawn particle
	var part := PART.instantiate()
	if has_won:
		part.hue = 60
		if child_inside:
			part.set_meta(&"fast", true)
			part.velocity *= 10
	# TODO: This more effectively?
	particles_parent.add_child(part)
	particles_parent.move_child(part, 0)
	return part

func _on_body_entered(body: Node2D) -> void:
	win()
	child_inside = true
	child_inside_time = time
	
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
#		print("%s vs %s" % [str(child.velocity), str(new.velocity)])
		child.add_sibling(new)

func _on_body_exited(body: Node2D) -> void:
	child_inside = false

"""
CREATE

floatA = 0
floatY = 0
starA = 0
image_speed = 0
alarm[0] = 6
instance_create((x + 16), (y + 16), oGoalParticle)
winA = 0
hasWon = 0
type = 0
omegaID = -1

ALARM 0

alarm[0] = 6
part = instance_create((x + 16), (y + 16), oGoalParticle)
if ((instance_exists(oLevelWin) && (!instance_exists(oLevelOmega))) || type >= 3)
{
	with (oGoalParticle)
		hue = 50
}
if (type == 1)
{
	with (oGoalParticle)
		hue = 195
}

DRAW
floatA = ((floatA + 2.5) % 360)
floatY = (3 * sin(degtorad(floatA)))
starA = ((starA + 1) % 360)
winA *= 0.95
if hasWon
{
	if (type != 1)
	{
		draw_sprite(sprite_index, 2, x, (y + floatY))
		draw_sprite_ext(sprite_index, 3, x, (y + floatY), 1, 1, 0, c_white, winA)
	}
	else
	{
		draw_sprite(sprite_index, 5, x, (y + floatY))
		draw_sprite_ext(sprite_index, 6, x, (y + floatY), 1, 1, 0, c_white, winA)
	}
	draw_set_blend_mode(bm_add)
	draw_sprite_ext(sprOrbPart, 0, (x + 16), (y + 16), (2 * (1 - winA)), (2 * (1 - winA)), 0, c_white, (winA / 2))
	draw_set_blend_mode(bm_normal)
}
else if (type == 0)
	draw_sprite(sprite_index, 1, x, (y + floatY))
else if (type >= 3)
{
	draw_sprite(sprite_index, 2, x, (y + floatY))
	draw_set_blend_mode(bm_add)
	draw_sprite_ext(sprStarOutline, 0, (x + 16), (y + 16), 0.5, 0.5, (-starA), make_color_rgb(120, 120, 40), 1)
	draw_sprite_ext(sprStarOutline, 0, (x + 16), (y + 16), 0.3, 0.3, (-starA), make_color_rgb(120, 120, 40), 0.5)
	draw_set_blend_mode(bm_normal)
}
else if (type == 1)
	draw_sprite(sprite_index, 4, x, (y + floatY))

"""
