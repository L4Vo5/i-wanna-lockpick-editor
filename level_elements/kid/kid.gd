@tool
extends CharacterBody2D
class_name Kid

# WAITING4GODOT: Extra Area2D necessary because keys' Area2D's wouldn't detect the body_entered in time but do work with areas properly. https://github.com/godotengine/godot/issues/41648

@onready var sprite: AnimatedSprite2D = %AnimatedSprite2D
@onready var shadow: AnimatedSprite2D = %Shadow
@onready var snd_jump: AudioStreamPlayer = %Jump
@onready var snd_jump_2: AudioStreamPlayer = %Jump2
@onready var spr_brown_aura: Sprite2D = %SprBrownAura
@onready var spr_brown_aura_2: Sprite2D = %SprBrownAura2
@onready var spr_red_aura: Sprite2D = %SprRedAura
@onready var spr_green_aura: Sprite2D = %SprGreenAura
@onready var spr_blue_aura: Sprite2D = %SprBlueAura
@onready var aura_area: Area2D = %AuraArea

@onready var player_shine: Sprite2D = %PlayerShine

@onready var snd_master_equip: AudioStreamPlayer = %MasterEquip
@onready var snd_master_unequip: AudioStreamPlayer = %MasterUnequip
@onready var snd_master_anti_equip: AudioStreamPlayer = %MasterAntiEquip
@onready var equipped_master: Sprite2D = %EquippedMaster
@onready var spr_i_view: Sprite2D = %IView
@onready var spr_white_aura: Sprite2D = %SprWhiteAura
@onready var door_detect: ShapeCast2D = %DoorDetect
@onready var entry_detect: Area2D = %EntryDetect
@onready var collision_shape: CollisionShape2D = %CollisionShape2D

const GRAVITY := 0.4
const JUMP_1 := -8.5
const JUMP_2 := -7.0
const MAX_VSPEED := 9.0
const JUMP_REDUCTION := 0.45

var level: Level:
	set(val):
		_disconnect_level()
		level = val
		_connect_level()

func _ready() -> void:
	aura_area.body_entered.connect(_on_aura_touch_door)
	entry_detect.area_entered.connect(_on_entry_detect_area_entered)
	entry_detect.area_exited.connect(_on_entry_detect_area_exited)

func _physics_process(_delta: float) -> void:
	if Global.in_editor: return
	if level.in_transition(): return
	if spr_i_view.visible:
		spr_i_view.modulate = Rendering.i_view_palette[1]
	update_on_floor()
	on_ceiling = test_move(global_transform, Vector2(0, -1))
	
	
	var current_speed := 3
	if on_floor: # and velocity.y == 0:
		if Input.is_action_pressed(&"fast"):
			current_speed = 6 if not Global.settings.is_autorun_on else 3
		else:
			current_speed = 3 if not Global.settings.is_autorun_on else 6
	if Input.is_action_pressed(&"slow"):
		current_speed = 1
	
	# detect vertically before the fall/jump logic
	# so if you collide with a door from below, you don't stop and end up with velocity.y = 0
	detect_doors(velocity * Vector2(current_speed, 1))
	
	_animate_auras()
	run()
	fall_jump()
	anim()
	master_anim()
	
	# special case to avoid jumping over tiles at the very top
	if position.y < 0:
		var old_y := position.y
		position.y = 0
		move_and_collide(velocity * Vector2(current_speed, 0))
		position.y = old_y
	# same for the bottom
	elif position.y > level.level_data.size.y + 10:
		var old_y := position.y
		position.y = level.level_data.size.y + 10
		move_and_collide(velocity * Vector2(current_speed, 0))
		position.y = old_y
	else:
		move_and_collide(velocity * Vector2(current_speed, 0))
	# another special case: collide with level edges
	if level:
		var left: float = collision_shape.global_position.x - collision_shape.shape.extents.x
		var right: float = collision_shape.global_position.x + collision_shape.shape.extents.x
		if left <= 0:
			position.x += -left+1
		if right >= level.level_data.size.x:
			position.x += level.level_data.size.x - right - 1
	move_and_collide(velocity * Vector2(0, 1))
	# needs to stay updated for the level to know if it's save to save undo state
	update_on_floor()
	
	# another special case
	if position.y > level.level_data.size.y + 128:
		level.undo()

func _unhandled_key_input(event: InputEvent) -> void:
	if !level: return
	if event.is_action_pressed(&"master"):
		level.logic.update_master_equipped(true, true)
	if event.is_action_pressed(&"enter_level"):
		if entry_detect.has_overlapping_areas():
			var entry: Entry = entry_detect.get_overlapping_areas()[0].get_parent()
			entry.enter()

var on_floor := true
var on_ceiling := false
var d_jumps := 1

func update_on_floor() -> void:
	if velocity.y >= 0:
		on_floor = test_move(global_transform, Vector2(0, GRAVITY))
		if on_floor:
			velocity.y = 0
	else:
		on_floor = false

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
	shadow.flip_h = sprite.flip_h

# Necessary for undo/redo
var is_pressing_jump := Input.is_action_pressed(&"jump")

func fall_jump() -> void:
	var last_is_pressing_jump := is_pressing_jump
	is_pressing_jump = Input.is_action_pressed(&"jump")
	var jump_just_pressed := is_pressing_jump and not last_is_pressing_jump
	var jump_just_released := (not is_pressing_jump) and last_is_pressing_jump
	if on_floor:
		d_jumps = 1
		velocity.y = 0
		if jump_just_pressed:
			velocity.y = JUMP_1 + GRAVITY
			snd_jump.play()
	else:
		velocity.y += GRAVITY
		if velocity.y > MAX_VSPEED:
			velocity.y = MAX_VSPEED
		if jump_just_pressed and d_jumps > 0:
			d_jumps -= 1
			velocity.y = JUMP_2 + GRAVITY
			snd_jump_2.play()
		elif jump_just_released and velocity.y < 0:
			velocity.y *= JUMP_REDUCTION
	
	if on_ceiling and velocity.y < 0:
		velocity.y = 0

func detect_doors(vel: Vector2) -> void:
	for vec in [
		vel * Vector2(1,0), # horizontal movement
		vel * Vector2(0, 1) if vel.y != 0 else Vector2(0, 1) # vertical movement (check below if stopped)
	]:
		door_detect.target_position = vec
		door_detect.force_shapecast_update()
		var colliders := range(door_detect.get_collision_count()).map(
			func(i: int) -> Object:
				return door_detect.get_collider(i)
		)
		var has_wall := false
		for collider in colliders:
			if not collider.get_parent() is Door:
				has_wall = true
		if has_wall:
			return
		for collider in colliders:
	#		var info = move_and_collide(vec, true)
	#		print("checking collision with vector %s" % vec)
	#		if info != null:
	#			print("success")
	#			var collider = info.get_collider()
			if collider.get_parent() is Door:
				interact_with_door(collider.get_parent())
				if vel.y < 0 and vec.y < 0:
					vel.y = 0

func interact_with_door(door: Door) -> void:
	level.logic.try_open_door(door)

func anim() -> void:
	if velocity.y < 0:
		sprite.play(&"jump")
	elif velocity.y > 0:
		sprite.play(&"fall")
	elif velocity.x == 0:
		sprite.play(&"idle")
	else:
		sprite.play(&"walk")
	shadow.animation = sprite.animation
	shadow.frame = sprite.frame

## logically updates area status
# (sprites' visibility is used to determine active auras)
func update_auras() -> void:
	if !level: return
	var red_amount: int = level.logic.key_counts[Enums.Colors.Red].real_part
	var green_amount: int = level.logic.key_counts[Enums.Colors.Green].real_part
	var blue_amount: int = level.logic.key_counts[Enums.Colors.Blue].real_part
	var brown_amount: int = level.logic.key_counts[Enums.Colors.Brown].real_part
	
	# Pack the visibility status into a binary number. I swear this makes the code simpler.
	assert(spr_brown_aura.frame in [0, 1])
	var visible_status_before := spr_brown_aura.frame + \
								(int(spr_red_aura.visible) << 1) + \
								(int(spr_blue_aura.visible) << 2) + \
								(int(spr_green_aura.visible) << 3) + \
								(int(spr_brown_aura.visible) << 4)
	spr_red_aura.visible = red_amount >= 1
	spr_green_aura.visible = green_amount >= 5
	spr_blue_aura.visible = blue_amount >= 3
	spr_brown_aura.visible = brown_amount != 0
	var mat : CanvasItemMaterial = spr_brown_aura.material
	if brown_amount > 0:
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_SUB
		spr_brown_aura.frame = 0
	elif brown_amount < 0:
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		spr_brown_aura.frame = 1
		
	var visible_status_after := spr_brown_aura.frame + \
								(int(spr_red_aura.visible) << 1) + \
								(int(spr_blue_aura.visible) << 2) + \
								(int(spr_green_aura.visible) << 3) + \
								(int(spr_brown_aura.visible) << 4)
	# This will be true if and only if any of them are now visible (thus active)
	# Process all doors the area is touching to take into account the newly updated aura
	if (visible_status_before | visible_status_after) - visible_status_before != 0:
		for body in aura_area.get_overlapping_bodies():
			_on_aura_touch_door(body)
	

## animates the auras
func _animate_auras() -> void:
	if spr_brown_aura.visible:
		spr_brown_aura.rotation_degrees = fmod(spr_brown_aura.rotation_degrees + 2.5, 360)
	else:
		spr_brown_aura.rotation_degrees = 0
	# brown area 2 is added just in case there's a pure black or white background,
	# in which case the brown and -brown areas respectively would normally be invisible
	spr_brown_aura_2.visible = spr_brown_aura.visible
	spr_brown_aura_2.frame = spr_brown_aura.frame + 2
	spr_brown_aura_2.rotation_degrees = spr_brown_aura.rotation_degrees

func _on_aura_touch_door(body: Node2D) -> void:
	var door: Door = body.get_parent()
	assert(door != null)
	level.logic.apply_auras_on_door(door)

func _connect_level() -> void:
	if !level: return
	_on_changed_i_view(false)
	update_auras()

func _disconnect_level() -> void:
	if !level: return

func _on_changed_i_view(show_anim := true) -> void:
	spr_i_view.visible = level.logic.i_view
	if show_anim:
		spr_white_aura.animate()
	level.logic.update_master_equipped()

func master_equipped_sounds(last_master_equipped: ComplexNumber) -> void:
	if last_master_equipped.is_zero():
		if not level.logic.master_equipped.is_zero():
			if level.logic.master_equipped.is_negative():
				snd_master_anti_equip.play()
			else:
				snd_master_equip.play()
	else:
		if level.logic.master_equipped.is_zero():
			snd_master_unequip.play()

func master_anim() -> void:
	if level.logic.master_equipped.is_zero():
		player_shine.hide()
		equipped_master.hide()
		return
	player_shine.show()
	equipped_master.show()
	equipped_master.frame = 0 if not level.logic.master_equipped.is_negative() else 1
	player_shine.modulate = Color8(180, 180, 50) if not level.logic.master_equipped.is_negative() else Color8(50, 50, 180)
	var alpha := 0.8 + 0.2 * (sin(deg_to_rad(Global.physics_step * 4 % 360)))
	equipped_master.modulate.a = alpha * 0.6
	player_shine.scale = Vector2(alpha, alpha)

func _on_entry_detect_area_entered(area: Area2D) -> void:
	area.get_parent().player_touching()
func _on_entry_detect_area_exited(area: Area2D) -> void:
	area.get_parent().player_stopped_touching()

# Returns a Callable that must be called to bring the kid back to whatever state it was in when this function was called
func get_undo_action() -> Callable:
	return _set_state.bind([
		position,
		velocity,
		d_jumps,
		sprite.flip_h,
		level.logic.master_equipped.duplicated(),
		on_floor,
		is_pressing_jump,
	])

func _set_state(vars: Array) -> void:
	position = vars[0]
	velocity = vars[1]
	d_jumps = vars[2]
	sprite.flip_h = vars[3]
	shadow.flip_h = sprite.flip_h
	# TODO: handle this elsewhere? too lazy now to figure it out
	level.logic.master_equipped.set_to_this(vars[4])
	var was_on_floor: bool = vars[5]
	if not was_on_floor:
		is_pressing_jump = vars[6]
