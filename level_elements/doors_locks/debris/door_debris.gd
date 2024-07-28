@tool
extends Node2D

var velocity := Vector2.ZERO
var gravity := 0.0
@export var color := Enums.Colors.White
@export var is_glitched_color := false
@onready var glitch: Sprite2D = %Glitch
var can_move := false

func _ready() -> void:
	velocity.y = randf_range(-4, -3)
	velocity.x = randf_range(-1.2, 1.2)
	gravity = randf_range(0.4, 0.5)
	glitch.material = glitch.material.duplicate()

func _physics_process(_delta: float) -> void:
	if not can_move:
		queue_redraw()
		return
	position += velocity
	velocity.y += gravity
	modulate.a -= 0.04
	if modulate.a <= 0.00:
		queue_free()
	glitch.material.set_shader_parameter(&"alpha", modulate.a)

func _draw() -> void:
	var frame := preload("res://level_elements/doors_locks/debris/frame.png")
	var light := preload("res://level_elements/doors_locks/debris/light.png")
	var middle := preload("res://level_elements/doors_locks/debris/middle.png")
	var dark := preload("res://level_elements/doors_locks/debris/dark.png")
	draw_texture(frame, Vector2.ZERO)
	glitch.hide()
	if is_glitched_color:
		glitch.show()
		glitch.frame = 1
	if color == Enums.Colors.None:
		pass
	elif color == Enums.Colors.Glitch:
		glitch.show()
		glitch.frame = 0
	elif color == Enums.Colors.Pure:
		var anim_frame := floori(Global.time / Rendering.SPECIAL_ANIM_DURATION) % 4
		draw_texture_rect_region(preload("res://level_elements/doors_locks/textures/pure_gradient.png"), Rect2(1,1,14,14), Rect2(anim_frame,0,1,64)
		)
	elif color == Enums.Colors.Master:
		var anim_frame := floori(Global.time / Rendering.SPECIAL_ANIM_DURATION) % 4
		draw_texture_rect_region(preload("res://level_elements/doors_locks/textures/gold_gradient.png"), Rect2(1,1,14,14), Rect2(anim_frame,0,1,64)
		)
	elif color == Enums.Colors.Stone:
		draw_texture_rect_region(preload("res://level_elements/doors_locks/textures/stone_texture.png"), Rect2(1,1,14,14), Rect2(0,0,14,14))
		pass
	else:
		draw_texture(light, Vector2(1,1), Rendering.color_colors[color][1])
		draw_texture(middle, Vector2(4,4), Rendering.color_colors[color][0])
		draw_texture(dark, Vector2(1,2), Rendering.color_colors[color][2])
