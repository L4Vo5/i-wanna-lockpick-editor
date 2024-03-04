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

const GRAVITY := 0.4
const JUMP_1 := -8.5
const JUMP_2 := -7.0
const MAX_VSPEED := 9.0
const JUMP_REDUCTION := 0.45

var master_equipped := ComplexNumber.new()
signal changed_autorun

var level: Level:
	set(val):
		# TODO: rename should_update_gates?
		if level:
			level.should_update_gates.disconnect(update_auras)
		level = val
		if level:
			level.should_update_gates.connect(update_auras)

func _ready() -> void:
	aura_area.body_entered.connect(_on_aura_touch_door)
	Global.changed_level.connect(connect_level)
	connect_level()
	entry_detect.area_entered.connect(_on_entry_detect_area_entered)
	entry_detect.area_exited.connect(_on_entry_detect_area_exited)

func _physics_process(_delta: float) -> void:
	if Global.in_editor: return
	if spr_i_view.visible:
		spr_i_view.modulate = Rendering.i_view_palette[1]
	update_on_floor()
	on_ceiling = test_move(global_transform, Vector2(0, -1))
	
	
	var current_speed := 3
	if on_floor: # and velocity.y == 0:
		if Input.is_action_pressed(&"fast"):
			current_speed = 6 if not Global.current_level.is_autorun_on else 3
		else:
			current_speed = 3 if not Global.current_level.is_autorun_on else 6
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
	
	move_and_collide(velocity * Vector2(current_speed, 0))
	move_and_collide(velocity * Vector2(0, 1))
	# needs to stay updated for the level to know if it's save to save undo state
	update_on_floor()

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_instance_valid(Global.current_level): return
	if event.is_action_pressed(&"master"):
		update_master_equipped(true, true)
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
var is_pressing_jump := false

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
	shadow.animation = sprite.animation
	shadow.frame = sprite.frame

## logically updates area status
# (sprites' visibility is used to determine active auras)
func update_auras() -> void:
	if not is_instance_valid(Global.current_level): return
	var red_amount: int = Global.current_level.key_counts[Enums.colors.red].real_part
	var green_amount: int = Global.current_level.key_counts[Enums.colors.green].real_part
	var blue_amount: int = Global.current_level.key_counts[Enums.colors.blue].real_part
	var brown_amount: int = Global.current_level.key_counts[Enums.colors.brown].real_part
	
	# Pack the visibility status into a binary number. I swear this makes the code simpler.
	var visible_status_before := int(spr_red_aura.visible) + \
								(int(spr_blue_aura.visible) << 1) + \
								(int(spr_green_aura.visible) << 2) + \
								(int(spr_brown_aura.visible) << 3)
	spr_red_aura.visible = red_amount >= 1
	spr_green_aura.visible = green_amount >= 5
	spr_blue_aura.visible = blue_amount >= 3
	spr_brown_aura.visible = brown_amount != 0
	var visible_status_after := int(spr_red_aura.visible) + \
								(int(spr_blue_aura.visible) << 1) + \
								(int(spr_green_aura.visible) << 2) + \
								(int(spr_brown_aura.visible) << 3)
	# This will be true if and only if any of them are now visible (thus active)
	# Process all doors the area is touching to take into account the newly updated aura
	if (visible_status_before | visible_status_after) - visible_status_before != 0:
		for body in aura_area.get_overlapping_bodies():
			_on_aura_touch_door(body)
	
	var mat : CanvasItemMaterial = spr_brown_aura.material
	if brown_amount > 0:
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_SUB
		spr_brown_aura.frame = 0
	elif brown_amount < 0:
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		spr_brown_aura.frame = 1

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
	update_auras() # recalculate the auras this frame just in case lol
	var door: Door = body.get_parent()
	assert(door != null)
	if spr_red_aura.visible:
		door.break_curse_ice()
	if spr_green_aura.visible:
		door.break_curse_erosion()
	if spr_blue_aura.visible:
		door.break_curse_paint()
	if spr_brown_aura.visible:
		var brown_amount: int = Global.current_level.key_counts[Enums.colors.brown].real_part
		if brown_amount < 0:
			door.break_curse_brown()
		elif brown_amount > 0:
			door.curse_brown()

func connect_level() -> void:
	if is_instance_valid(Global.current_level):
		Global.current_level.changed_i_view.connect(_on_changed_i_view)
		_on_changed_i_view(false)
		Global.current_level.key_counts[Enums.colors.master].changed.connect(update_master_equipped.bind(false, false, true))

func _on_changed_i_view(show_anim := true) -> void:
	spr_i_view.visible = Global.current_level.i_view
	if show_anim:
		spr_white_aura.animate()
	update_master_equipped()

func update_master_equipped(switch_state := false, play_sounds := true, unequip_if_different := false) -> void:
	# if the objective is for it to be "on" or not
	var obj_on := (master_equipped.is_zero() and switch_state) or (not master_equipped.is_zero() and not switch_state)
	if not obj_on:
		master_equipped.set_to(0, 0)
	else:
		var original_count := master_equipped.duplicated()
		var i_view: bool = Global.current_level.i_view
		master_equipped.set_to(0,0)
		if not i_view:
			master_equipped.real_part = signi(Global.current_level.key_counts[Enums.colors.master].real_part)
		else:
			master_equipped.imaginary_part = signi(Global.current_level.key_counts[Enums.colors.master].imaginary_part)
		if unequip_if_different and not original_count.is_equal_to(master_equipped):
			master_equipped.set_to(0, 0)
	if play_sounds:
		_master_equipped_sounds()
	else:
		_last_master_equipped.set_to_this(master_equipped)

var _last_master_equipped := ComplexNumber.new()
func _master_equipped_sounds() -> void:
	if _last_master_equipped.is_zero():
		if not master_equipped.is_zero():
			if master_equipped.is_negative():
				snd_master_anti_equip.play()
			else:
				snd_master_equip.play()
	else:
		if master_equipped.is_zero():
			snd_master_unequip.play()
	_last_master_equipped.set_to_this(master_equipped)

func master_anim() -> void:
	if master_equipped.is_zero():
		player_shine.hide()
		equipped_master.hide()
		return
	player_shine.show()
	equipped_master.show()
	equipped_master.frame = 0 if not master_equipped.is_negative() else 1
	player_shine.modulate = Color8(180, 180, 50) if not master_equipped.is_negative() else Color8(50, 50, 180)
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
		master_equipped.duplicated(),
		_last_master_equipped.duplicated(),
		is_pressing_jump,
		on_floor
	])

func _set_state(vars: Array) -> void:
	position = vars[0]
	velocity = vars[1]
	d_jumps = vars[2]
	sprite.flip_h = vars[3]
	shadow.flip_h = sprite.flip_h
	master_equipped.set_to_this(vars[4])
	_last_master_equipped.set_to_this(vars[5])
	var was_on_floor = vars[7]
	if not was_on_floor:
		is_pressing_jump = vars[6]
