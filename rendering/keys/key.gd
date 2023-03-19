@tool
extends Area2D
class_name Key

@export var key_data: KeyData:
	set(val):
		if key_data == val: return
		if is_instance_valid(key_data):
			key_data.changed.disconnect(update_visual)
		key_data = val
		if is_instance_valid(key_data):
			key_data.changed.connect(update_visual)
@export var in_keypad := false

@onready var shadow: Sprite2D = %Shadow
@onready var fill: Sprite2D = %Fill
@onready var outline: Sprite2D = %Outline
@onready var special: Sprite2D = %Special
@onready var glitch: Sprite2D = %SprGlitch

@onready var snd_pickup: AudioStreamPlayer = %Pickup
@onready var number: Label = %Number
@onready var symbol: Sprite2D = %Symbol

var is_ready := false
func _ready() -> void:
	is_ready = true
	if in_keypad:
		shadow.hide()
		collision_layer = 0
		collision_mask = 0
	body_entered.connect(on_collide)
	update_visual()
	_connect_global_level()
	Global.changed_level.connect(_connect_global_level)

func _connect_global_level() -> void:
	if in_keypad: return
	if is_instance_valid(Global.current_level):
		# needed to access the level glitch color (only necessary if it starts out not being glitch, which shouldn't happen in-game, but I want things to work while I test)
		if key_data.color == Enums.color.glitch:
			update_visual()
		Global.current_level.changed_glitch_color.connect(update_visual)

func _process(delta: float) -> void:
	if key_data.color in [Enums.color.master, Enums.color.pure]:
		var frame := floori(Global.time / Rendering.SPECIAL_ANIM_SPEED) % 4
		if frame == 3:
			frame = 1
		special.frame = (special.frame % 4) + frame * 4

func set_special_texture(color: Enums.color) -> void:
	match color:
		Enums.color.stone:
			special.texture = preload("res://rendering/keys/spr_key_stone.png")
			special.vframes = 2
		Enums.color.master:
			special.texture = preload("res://rendering/keys/spr_key_master.png")
			special.vframes = 4
		Enums.color.pure:
			special.texture = preload("res://rendering/keys/spr_key_pure.png")
			special.vframes = 4

func update_visual() -> void:
	if not is_ready: return
	if not is_instance_valid(key_data): return
	fill.hide()
	outline.hide()
	special.hide()
	glitch.hide()
	number.hide()
	symbol.hide()
	# get the outline / shadow / fill
	var spr_frame = {
		key_data.key_types.exact: 1,
		key_data.key_types.star: 2,
		key_data.key_types.unstar: 3,
	}.get(key_data.type)
	if spr_frame == null: spr_frame = 0
	shadow.frame = spr_frame
	fill.frame = spr_frame
	outline.frame = spr_frame
	special.frame = spr_frame
	glitch.frame = spr_frame
	if key_data.color == Enums.color.master and key_data.type == key_data.key_types.add:
		shadow.frame = 4
	if key_data.color in [Enums.color.master, Enums.color.pure, Enums.color.stone]:
		special.show()
		set_special_texture(key_data.color)
	elif key_data.color == Enums.color.glitch:
		glitch.show()
		if not in_keypad and is_instance_valid(Global.current_level) and Global.current_level.glitch_color != Enums.color.glitch:
			if Global.current_level.glitch_color in [Enums.color.master, Enums.color.pure, Enums.color.stone]:
				special.show()
				set_special_texture(Global.current_level.glitch_color)
				special.frame = special.frame % 4 + 4 * (special.vframes - 1)
			else:
				fill.show()
				fill.frame = fill.frame % 4 + 4
				fill.modulate = Rendering.key_colors[Global.current_level.glitch_color]
	else:
		fill.show()
		outline.show()
		fill.modulate = Rendering.key_colors[key_data.color]
	
	
	# draw the number
	if key_data.type == key_data.key_types.add or key_data.type == key_data.key_types.exact:
		number.show()
		number.text = str(key_data.amount)
		if number.text == "1":
			number.text = ""
		# sign color
		var i := 1 if key_data.amount.is_negative() else 0
		number.add_theme_color_override(&"font_color", Rendering.key_number_colors[i])
		number.add_theme_color_override(&"font_outline_color", Rendering.key_number_colors[i])
		number.add_theme_color_override(&"font_shadow_color", Rendering.key_number_colors[1-i])
	# or the symbol
	else:
		var frame = {
			key_data.key_types.flip: 0,
			key_data.key_types.rotor: 1,
			key_data.key_types.rotor_flip: 2,
		}.get(key_data.type)
		if frame != null:
			symbol.frame = frame
			symbol.show()

func on_collide(who: Node2D) -> void:
	if key_data.is_spent: return
	on_pickup()

func on_pickup() -> void:
	if Global.print_actions:
		print("Picked up a key")
	key_data.is_spent = true
	var color := key_data.color
	if color == Enums.color.glitch:
		if not is_instance_valid(Global.current_level):
			printerr("Glitch key picked up, but there's no level")
		else:
			color = Global.current_level.glitch_color
	if Global.current_level.star_keys[color]:
		if key_data.type == key_data.key_types.unstar:
			Global.current_level.star_keys[color] = false
	else:
		match key_data.type:
			key_data.key_types.add:
				Global.current_level.key_counts[color].add(key_data.amount)
			key_data.key_types.exact:
				Global.current_level.key_counts[color].set_to_this(key_data.amount)
			key_data.key_types.rotor:
				Global.current_level.key_counts[color].rotor()
			key_data.key_types.flip:
				Global.current_level.key_counts[color].flip()
			key_data.key_types.rotor_flip:
				Global.current_level.key_counts[color].rotor().flip()
			key_data.key_types.star:
				Global.current_level.star_keys[color] = true
	hide()
	
	snd_pickup.pitch_scale = 1
	if key_data.color == Enums.color.master:
		snd_pickup.stream = preload("res://rendering/keys/master_pickup.wav")
		if key_data.amount.is_negative():
			snd_pickup.pitch_scale = 0.82
	elif key_data.type in [key_data.key_types.flip, key_data.key_types.rotor, key_data.key_types.rotor_flip]:
		snd_pickup.stream = preload("res://rendering/keys/signflip_pickup.wav")
	elif key_data.type == key_data.key_types.star:
		snd_pickup.stream = preload("res://rendering/keys/star_pickup.wav")
	elif key_data.type == key_data.key_types.unstar:
		snd_pickup.stream = preload("res://rendering/keys/unstar_pickup.wav")
	elif key_data.amount.is_negative():
		snd_pickup.stream = preload("res://rendering/keys/negative_pickup.wav")
	else:
		snd_pickup.stream = preload("res://rendering/keys/key_pickup.wav")
	snd_pickup.play()
