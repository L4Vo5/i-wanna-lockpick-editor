@tool
extends CharacterBody2D
class_name Kid

@onready var sprite := %AnimatedSprite2D as AnimatedSprite2D
@onready var snd_jump := %Jump as AudioStreamPlayer
@onready var snd_jump_2 := %Jump2 as AudioStreamPlayer
@onready var spr_brown_aura: Sprite2D = %SprBrownAura
@onready var spr_brown_aura_2: Sprite2D = %SprBrownAura2
@onready var spr_red_aura: Sprite2D = %SprRedAura
@onready var spr_green_aura: Sprite2D = %SprGreenAura
@onready var spr_blue_aura: Sprite2D = %SprBlueAura
@onready var aura_area: Area2D = %AuraArea

const gravity := 0.4

func _ready() -> void:
	aura_area.body_entered.connect(_on_aura_touch_door)

func _physics_process(delta: float) -> void:
	if Global.in_editor: return
	on_floor = test_move(transform, Vector2(0, gravity))
	on_ceiling = test_move(transform, Vector2(0, -1))
	auras()
	run()
	detect_doors()
	fall_jump()
	anim()
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
	for vec in [
		velocity * Vector2(1,0), # horizontal movement
		velocity * Vector2(0, 1) if velocity.y != 0 else Vector2(0, 1) # vertical movement (check below if stopped)
	]:
		var info = move_and_collide(vec, true)
		if info != null:
			var collider = info.get_collider()
			if collider.get_parent() is Door:
				interact_with_door(collider.get_parent())
				if velocity.y < 0 and vec.y < 0:
					velocity.y = 0

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

func auras() -> void:
	if not is_instance_valid(Global.current_level): return
	spr_red_aura.visible = Global.current_level.key_counts[Enums.color.red].real_part >= 1
	spr_green_aura.visible = Global.current_level.key_counts[Enums.color.green].real_part >= 5
	spr_blue_aura.visible = Global.current_level.key_counts[Enums.color.blue].real_part >= 3
	
	spr_brown_aura.rotation_degrees = fmod(spr_brown_aura.rotation_degrees + 2.5, 360)
	var brown_amount: int = Global.current_level.key_counts[Enums.color.brown].real_part
	spr_brown_aura.visible = brown_amount != 0
	var mat : CanvasItemMaterial = spr_brown_aura.material
	if brown_amount > 0:
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_SUB
		spr_brown_aura.frame = 0
	elif brown_amount < 0:
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		spr_brown_aura.frame = 1
	else:
		spr_brown_aura.rotation_degrees = 0
	# brown area 2 is added just in case there's a pure black or white background,
	# in which case the brown and -brown areas respectively would normally be invisible
	spr_brown_aura_2.visible = spr_brown_aura.visible
	spr_brown_aura_2.frame = spr_brown_aura.frame + 2
	spr_brown_aura_2.rotation_degrees = spr_brown_aura.rotation_degrees

func _on_aura_touch_door(body: Node2D) -> void:
	auras() # recalculate the auras this frame just in case lol
	var door: Door = body.get_parent()
	assert(door != null)
	if spr_red_aura.visible:
		door.break_curse_ice()
	if spr_green_aura.visible:
		door.break_curse_eroded()
	if spr_blue_aura.visible:
		door.break_curse_painted()
	if spr_brown_aura.visible:
		var brown_amount: int = Global.current_level.key_counts[Enums.color.brown].real_part
		if brown_amount < 0:
			door.break_curse_brown()
		elif brown_amount > 0:
			door.curse_brown()
