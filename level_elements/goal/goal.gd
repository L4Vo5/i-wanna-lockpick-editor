@tool
extends Area2D
class_name LevelGoal

var has_won := false
var funny_animation := false
var time := 0
var win_time := 0
var funny_animation_time := 0
var level: Level
const PART := preload("res://level_elements/goal/goal_particle.tscn")
@onready var particles_parent: Node2D = %Particles
@onready var sprite: Sprite2D = %Sprite
@onready var sprite_parent: Node2D = %SpriteParent
@onready var snd_win: AudioStreamPlayer = %Win

var custom_pos: Vector2: set = set_pos
func set_pos(pos: Vector2) -> void:
	custom_pos = pos
	if is_node_ready():
		sprite_parent.position = custom_pos

func _ready() -> void:
	sprite_parent.position = custom_pos
	area_entered.connect(_on_body_entered)
	if level and level.gameplay_manager and level.gameplay_manager.has_won_current_level():
		win(true)
	preprocess(58)

func _physics_process(_delta: float) -> void:
	# Should create particle on first step
	var step = 3 if funny_animation else 6
	
	if funny_animation:
		var time_since := time - funny_animation_time
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

func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		sprite.position = Vector2.ZERO

func win(visual_only: bool) -> void:
	if not visual_only:
		level.gameplay_manager.win()
		snd_win.play()
	has_won = true
	win_time = time
	sprite.frame = 2

func undo_win() -> void:
	has_won = false
	sprite.frame = 1
	
	for child in particles_parent.get_children():
		child.hue = 120

func spawn_particle(put_first := true) -> Node2D:
	# Spawn particle
	var part := PART.instantiate()
	part.position = sprite_parent.position
	if has_won:
		part.hue = 60
	if funny_animation:
		part.set_meta(&"fast", true)
		part.velocity *= 10
	# TODO: This more effectively?
	particles_parent.add_child(part)
	if put_first:
		particles_parent.move_child(part, 0)
	return part

func _on_body_entered(_body: Node2D) -> void:
	win(false)

func start_funny_animation() -> void:
	if funny_animation: return
	funny_animation = true
	funny_animation_time = time + 60
	
	for child in particles_parent.get_children():
		if child.has_meta(&"fast"): continue
		child.set_meta(&"fast", true)
		child.velocity *= 10

func stop_funny_animation() -> void:
	funny_animation = false

func preprocess(amount: int) -> void:
	assert(PerfManager.start("Goal::preprocess (%d)" % amount))
	for i in amount:
		_physics_process(0)
		for part in particles_parent.get_children():
			part._physics_process(0)
	assert(PerfManager.end("Goal::preprocess (%d)" % amount))
