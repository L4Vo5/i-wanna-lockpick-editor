@tool
extends Node2D
class_name Transition

@onready var background: ColorRect = %Background

@onready var title_text: OutlineText = %Title
@onready var name_text: OutlineText = %Name
@onready var contributor_text: OutlineText = %Contributor

var text_offset:= 0.0
var wiggle_angle:= 0.0
var title_wiggle := Vector2(0, 0)
var name_wiggle := Vector2(0, 0)

var animation_stage := -1
var animation_timer:= 0.0

# timings
## time for background alpha to reach 1
var fade_in_length:= 0.0

## time when the fall starts
var fall_start:= 0.0

## time for the text to reach the center
var fall_length:= 0.0

## time you need to wait after fall_length
var hold_length := 0.0

## whether you can press jump or restart to finish early
var can_finish_early: bool = true

## time for background alpha to reach 0
var fade_out_length:= 0.0

signal finished_animation

func cancel() -> void:
	background.modulate.a = 0
	text_offset = -500
	animation_stage = -1
	hide()

func set_timings(fade_in: float, fall_offset: float, fall: float, hold: float, finish_early: bool, fade_out: float) -> void:
	if animation_stage != -1:
		# already playing animation
		if animation_stage == 2:
			# just fade out
			cancel()
		else:
			return
	fade_in_length = fade_in
	fall_start = fall_offset
	fall_length = fall
	hold_length = hold
	can_finish_early = finish_early
	fade_out_length = fade_out

func start_animation(name_str: String, title: String = "", contributor: String = "") -> void:
	if animation_stage != -1:
		# already playing animation
		if animation_stage == 2:
			# just fade out
			cancel()
		else:
			return
	animation_stage = 0
	name_text.text = name_str
	title_text.text = title
	contributor_text.text = contributor
	animation_timer = 0
	text_offset = -500
	show()

func win_animation(text: String):
	set_timings(1.2, 0, 1.6, 1.6, true, 0.7)
	start_animation(text)

func level_enter_animation(name_str: String, title: String = "", contributor: String = ""):
	set_timings(0.7, 0.7, 0.8, 2.2, true, 0.7)
	start_animation(name_str, title, contributor)

func world_enter_animation():
	set_timings(0.5, 0, 0.5, 0.5, false, 0.5)
	start_animation("")

func _init() -> void:
	visibility_changed.connect(func(): set_process(visible))
	set_process(visible)

func _process(delta):
	if animation_timer < 0 or animation_stage < 0:
		hide()
	elif animation_stage == 0:
		# fade in
		if animation_timer >= fall_start + fall_length:
			background.modulate.a = 1
			text_offset = 0
			animation_stage = 1
			animation_timer = 0
		else:
			if animation_timer >= fall_start:
				var angle = 90 * (animation_timer - fall_start) / fall_length
				text_offset = (sin(deg_to_rad(angle)) - 1) * 500
			else:
				text_offset = -500
			background.modulate.a = min(animation_timer / fade_in_length, 1)
	elif animation_stage == 1:
		# hold
		var finish_animation: bool = false
		if can_finish_early:
			if Input.is_action_just_pressed(&"restart"):
				finish_animation = true
			if Input.is_action_just_pressed(&"jump"):
				finish_animation = true
		if finish_animation or animation_timer >= hold_length:
			animation_stage = 2
			animation_timer = 0
			finished_animation.emit()
			for con in finished_animation.get_connections():
				finished_animation.disconnect(con.callable)
	elif animation_stage == 2:
		# fade out
		if animation_timer >= fade_out_length:
			background.modulate.a = 0
			text_offset = -500
			animation_stage = -1
			hide()
		else:
			var angle = 90 * (1 - animation_timer / fade_out_length)
			text_offset = (sin(deg_to_rad(angle)) - 1) * 500
			background.modulate.a = 1 - animation_timer / fade_out_length
	wiggle_angle += 280 * delta
	if wiggle_angle >= 360:
		wiggle_angle -= 360
	title_wiggle = Vector2.from_angle(deg_to_rad(wiggle_angle)) * 3
	name_wiggle = Vector2.from_angle(deg_to_rad(wiggle_angle + 50)) * 6
	update_visual()
	animation_timer += delta

func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		text_offset = 0
		title_wiggle = Vector2.ZERO
		name_wiggle = Vector2.ZERO
		update_visual()

func update_visual():
	title_text.position = Vector2(400, 240 + text_offset) + title_wiggle
	name_text.position = Vector2(400, 304 + text_offset) + name_wiggle
	contributor_text.position = Vector2(400, 400 + text_offset) + title_wiggle
