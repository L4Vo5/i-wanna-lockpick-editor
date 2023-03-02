extends Area2D

@export var key_data: KeyData

@onready var shadow: Sprite2D = %Shadow
@onready var fill: Sprite2D = %Fill
@onready var outline: Sprite2D = %Outline
@onready var special: Sprite2D = %Special

@onready var snd_pickup: AudioStreamPlayer = %Pickup
@onready var number: Label = %Number
@onready var symbol: Sprite2D = %Symbol

const MULT = "×"


func _ready() -> void:
	body_entered.connect(on_collide)
	update_visual()

func _process(delta: float) -> void:
	if special.visible and special.vframes == 3:
		var frame := floori(Global.time / Rendering.SPECIAL_ANIM_SPEED) % 4
		if frame == 3:
			frame = 1
		special.frame = (special.frame % 4) + frame * 4

func update_visual() -> void:
	if key_data.color in [Enums.color.master, Enums.color.pure, Enums.color.stone, Enums.color.glitch]:
		fill.hide()
		outline.hide()
		special.show()
		match key_data.color:
			Enums.color.stone:
				special.texture = preload("res://rendering/keys/spr_key_stone.png")
				special.vframes = 1
			Enums.color.master:
				special.texture = preload("res://rendering/keys/spr_key_master.png")
				special.vframes = 3
			Enums.color.pure:
				special.texture = preload("res://rendering/keys/spr_key_pure.png")
				special.vframes = 3
	else:
		fill.show()
		outline.show()
		special.hide()
		fill.modulate = Rendering.key_colors[key_data.color]
	
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
	if key_data.color == Enums.color.master and key_data.type == key_data.key_types.add:
		shadow.frame = 4
	
	# draw the number
	if key_data.type == key_data.key_types.add or key_data.type == key_data.key_types.exact:
		number.show()
		symbol.hide()
		number.text = ""
		# simple case if no imaginary keys
		if key_data.amount.imaginary_part == 0:
			# don't draw a key with just 1
			if key_data.amount.real_part != 1:
				number.text += str(key_data.amount.real_part)
		# there's imaginary keys
		else:
			# don't draw a key with real part 0
			if key_data.amount.real_part != 0:
				number.text += str(key_data.amount.real_part)
				# draw a + if imaginary is positive (only if there's reals)
				if key_data.amount.imaginary_part > 0:
					number.text += "+"
			number.text += str(key_data.amount.imaginary_part)
			number.text += "i"
		# sign color
		# 0 = positive colors, 1 = negative colors
		var i := 0
		if key_data.amount.real_part == 0:
			i = 0 if key_data.amount.imaginary_part >= 0 else 1
		elif key_data.amount.imaginary_part == 0:
			i = 0 if key_data.amount.real_part >= 0 else 1
		# if they're both negative
		elif key_data.amount.real_part < 0 and key_data.amount.imaginary_part < 0:
			i = 1
		number.add_theme_color_override(&"font_color", Rendering.key_number_colors[i])
		number.add_theme_color_override(&"font_outline_color", Rendering.key_number_colors[i])
		number.add_theme_color_override(&"font_shadow_color", Rendering.key_number_colors[1-i])
	# or the symbol
	else:
		number.hide()
		var frame = {
			key_data.key_types.flip: 0,
			key_data.key_types.rotor: 1,
			key_data.key_types.rotor_flip: 2,
		}.get(key_data.type)
		if frame != null:
			symbol.frame = frame
			symbol.show()

func on_collide(_who: Node2D) -> void:
	if key_data.spent[0]: return
	on_pickup()

func on_pickup() -> void:
	if Global.print_actions:
		print("Picked up a key")
	key_data.spent[0] = true
	if Global.current_level.star_keys[key_data.color]:
		if key_data.type == key_data.key_types.unstar:
			Global.current_level.star_keys[key_data.color] = false
	else:
		match key_data.type:
			key_data.key_types.add:
				Global.current_level.key_counts[key_data.color].add(key_data.amount)
			key_data.key_types.exact:
				Global.current_level.key_counts[key_data.color] = key_data.amount
			key_data.key_types.rotor:
				Global.current_level.key_counts[key_data.color].rotor()
			key_data.key_types.flip:
				Global.current_level.key_counts[key_data.color].flip()
			key_data.key_types.rotor_flip:
				Global.current_level.key_counts[key_data.color].rotor().flip()
			key_data.key_types.star:
				Global.current_level.star_keys[key_data.color] = true
	hide()
	snd_pickup.play()
