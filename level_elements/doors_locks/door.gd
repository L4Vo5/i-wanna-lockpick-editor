@tool
extends MarginContainer
class_name Door

const LOCK := preload("res://level_elements/doors_locks/lock_visual.tscn")
const DEBRIS := preload("res://level_elements/doors_locks/debris/door_debris.tscn")
const FRAME_POS := preload("res://level_elements/doors_locks/door_frame_texture_pos.png")
const FRAME_NEG := preload("res://level_elements/doors_locks/door_frame_texture_neg.png")

var open_cooldown := 0.5
var can_open := true

@export var door_data: DoorData

@onready var color_light: NinePatchRect = %ColorLight
@onready var color_mid: NinePatchRect = %ColorMid
@onready var color_dark: NinePatchRect = %ColorDark
@onready var special_anim: Sprite2D = %SpecialAnim # master and pure
@onready var stone_texture: TextureRect = %StoneTexture
@onready var glitch: Control = %Glitch

@onready var frame_light: NinePatchRect = %FrameLight
@onready var frame_mid: NinePatchRect = %FrameMid
@onready var frame_dark: NinePatchRect = %FrameDark


@onready var static_body := %StaticBody2D as StaticBody2D
@onready var lock_holder := %LockHolder as Control

@onready var ice: MarginContainer = %Ice
@onready var paint: TextureRect = %Paint
@onready var erosion: MarginContainer = %Erosion
@onready var brown_curse: Control = %BrownCurse

@onready var snd_open: AudioStreamPlayer = %Open
@onready var copies: Label = %Copies

var using_i_view_colors := false

func _ready() -> void:
	static_body.disable_mode = CollisionObject2D.DISABLE_MODE_REMOVE
	if not Global.in_editor:
		door_data = door_data.duplicated()
	door_data.changed.connect(update_everything)
	update_everything()
	copies.minimum_size_changed.connect(position_copies)
	connect_level()
	Global.changed_level.connect(connect_level)

func connect_level() -> void:
	if is_instance_valid(Global.current_level):
		Global.current_level.changed_i_view.connect(_on_changed_i_view)
		_on_changed_i_view()

func _physics_process(_delta: float) -> void:
	special_anim.frame = floori(Global.time / Rendering.SPECIAL_ANIM_SPEED) % special_anim.hframes * special_anim.vframes
	
	var text := ""
	if not door_data.amount.is_value(1,0):
		text = "×" + str(door_data.amount)
	copies.text = text
	i_view_colors()

func update_everything() -> void:
	update_textures()
	update_locks()
	update_curses()

func position_copies() -> void:
	copies.size.x = size.x
	var diff := copies.size.x - size.x
	copies.position.x = -diff/2

func _on_changed_i_view() -> void:
	if not is_instance_valid(Global.current_level): return
	if not is_instance_valid(door_data): return
	var is_aligned := false
	var is_flipped := false
	if not Global.current_level.i_view and door_data.amount.real_part != 0:
		is_aligned = true
		if door_data.amount.real_part < 0:
			is_flipped = true
	if Global.current_level.i_view and door_data.amount.imaginary_part != 0:
		is_aligned = true
		if door_data.amount.imaginary_part < 0:
			is_flipped = true
	using_i_view_colors = not is_aligned
	if not using_i_view_colors:
		update_textures()
	for lock in door_data.locks:
		if not is_instance_valid(lock): continue
		lock.dont_show_frame = not is_aligned
		if Global.current_level.i_view:
			lock.rotation.set_to(0, 1)
		else:
			lock.rotation.set_to(1, 0)
		if is_flipped:
			lock.rotation.flip()

func i_view_colors() -> void:
	if not using_i_view_colors: return
	var hue := fmod((Global.physics_step * 0.75) / 255.0, 1.0)
	frame_light.modulate = Color.from_hsv(hue, Rendering.frame_s_v[1][0], Rendering.frame_s_v[1][1])
	frame_mid.modulate = Color.from_hsv(hue, Rendering.frame_s_v[0][0], Rendering.frame_s_v[0][1])
	frame_dark.modulate = Color.from_hsv(hue, Rendering.frame_s_v[2][0], Rendering.frame_s_v[2][1])

func update_textures() -> void:
	size = door_data.size
	position_copies()
	static_body.scale = size
	var frame_palette = Rendering.frame_colors[Enums.sign.positive if door_data.amount.real_part >= 0 else Enums.sign.negative]
	frame_light.modulate = frame_palette[1]
	frame_mid.modulate = frame_palette[0]
	frame_dark.modulate = frame_palette[2]
	i_view_colors()
	
	color_light.hide()
	color_mid.hide()
	color_dark.hide()
	special_anim.hide()
	stone_texture.hide()
	glitch.hide()
	
	var used_color := door_data.outer_color
	
	if used_color == Enums.colors.glitch:
		glitch.show()
		if door_data.glitch_color == Enums.colors.glitch:
			glitch.texture = preload("res://level_elements/doors_locks/glitch_door.png")
			return
		else:
			used_color = door_data.glitch_color
			glitch.texture = preload("res://level_elements/doors_locks/glitch_door_2.png")
			if used_color in [Enums.colors.master, Enums.colors.pure]:
				special_anim.show()
				special_anim.hframes = 1
				special_anim.scale = size / Vector2(1,58)
				special_anim.texture = {
					Enums.colors.master: preload("res://level_elements/doors_locks/gold_glitch_door.png"),
					Enums.colors.pure: preload("res://level_elements/doors_locks/pure_glitch_door.png")
				}[used_color]
				return
	
	if used_color in [Enums.colors.master, Enums.colors.pure]:
		special_anim.show()
		special_anim.scale = size / Vector2(1,64)
		special_anim.hframes = 4
		special_anim.texture = {
			Enums.colors.master: preload("res://level_elements/doors_locks/gold_gradient.png"),
			Enums.colors.pure: preload("res://level_elements/doors_locks/pure_gradient.png")
		}[used_color]
	elif used_color == Enums.colors.stone:
		stone_texture.show()
	else: # most colors
		color_light.show()
		color_mid.show()
		color_dark.show()
		color_light.modulate = Rendering.color_colors[used_color][1]
		color_mid.modulate = Rendering.color_colors[used_color][0]
		color_dark.modulate = Rendering.color_colors[used_color][2]

func update_locks() -> void:
	for lock in lock_holder.get_children():
		lock.queue_free()
	for lock in door_data.locks:
		var new_lock := LOCK.instantiate()
		new_lock.lock_data = lock
		lock_holder.add_child(new_lock)

func update_curses() -> void:
	ice.visible = door_data.get_curse(Enums.curse.ice)
	erosion.visible = door_data.get_curse(Enums.curse.eroded)
	paint.visible = door_data.get_curse(Enums.curse.painted)
	brown_curse.visible = door_data.get_curse(Enums.curse.brown)

func try_open() -> void:
	if not can_open: return
	var should_create_debris := false
	for i in Global.current_level.door_multiplier:
		# "opened", "master_key", "added_copy"
		var result := door_data.try_open()
		if result.opened:
			if result.added_copy:
				snd_open.stream = preload("res://level_elements/doors_locks/copy.wav")
			elif result.master_key:
				snd_open.stream = preload("res://level_elements/doors_locks/open_master.wav")
			elif door_data.locks.size() > 1:
				snd_open.stream = preload("res://level_elements/doors_locks/open_combo.wav")
			elif door_data.outer_color == Enums.colors.master:
				snd_open.stream = preload("res://level_elements/doors_locks/open_master.wav")
			else:
				snd_open.stream = preload("res://level_elements/doors_locks/open.wav")
			snd_open.play()
			should_create_debris = true
		if door_data.amount.is_zero():
			hide()
			static_body.process_mode = Node.PROCESS_MODE_DISABLED
			break
	if should_create_debris:
		create_debris()
	can_open = false
	get_tree().create_timer(open_cooldown).timeout.connect(func(): can_open = true)

# do the effects for the curses
func break_curse_ice() -> void:
	if not door_data.get_curse(Enums.curse.ice): return
	door_data.set_curse(Enums.curse.ice, false)

func break_curse_eroded() -> void:
	if not door_data.get_curse(Enums.curse.eroded): return
	door_data.set_curse(Enums.curse.eroded, false)

func break_curse_painted() -> void:
	if not door_data.get_curse(Enums.curse.painted): return
	door_data.set_curse(Enums.curse.painted, false)

func curse_brown() -> void:
	if door_data.get_curse(Enums.curse.brown): return
	door_data.set_curse(Enums.curse.brown, true)

func break_curse_brown() -> void:
	if not door_data.get_curse(Enums.curse.brown): return
	door_data.set_curse(Enums.curse.brown, false)

func create_debris() -> void:
	for x in floori(size.x / 16):
		for y in floori(size.y / 16):
			var debris := DEBRIS.instantiate()
			debris.can_move = true
			var timer := Timer.new()
			timer.timeout.connect(debris.queue_free)
			debris.add_child(timer)
			debris.color = door_data.outer_color
			if door_data.get_curse(Enums.curse.brown):
				debris.color = Enums.colors.brown
			elif door_data.outer_color == Enums.colors.glitch:
				debris.color = door_data.glitch_color
				debris.is_glitched_color = true
			debris.global_position = global_position
			debris.position.x += randf_range(-4, 4) + 16 * x
			debris.position.y += randf_range(0, 8) + 16 * y
			if Global.in_editor:
				add_child(debris)
			else:
				# TODO: don't put it on the root that's dum
				get_tree().root.add_child(debris)
			timer.start(20)
