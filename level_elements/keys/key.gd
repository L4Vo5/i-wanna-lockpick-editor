@tool
extends Control
class_name Key
## Key lol

signal picked_up
static var level_element_type := Enums.level_element_types.key

@export var key_data: KeyData:
	set(val):
		if key_data == val: return
		_disconnect_key_data()
		key_data = val
		_connect_key_data()
@export var hide_shadow := false
@export var ignore_position := false

@onready var shadow: Sprite2D = %Shadow
@onready var fill: Sprite2D = %Fill
@onready var outline: Sprite2D = %Outline
@onready var special: Sprite2D = %Special
@onready var glitch: Sprite2D = %SprGlitch

@onready var snd_pickup: AudioStreamPlayer = %Pickup
@onready var number: Label = %Number
@onready var symbol: Sprite2D = %Symbol
@onready var symbol_inf: Sprite2D = %SymbolInf
@onready var collision: Area2D = %Collision
#@onready var input_grabber: Control = $GuiInputGrabber

var level: Level = null:
	set(val):
		if level == val: return
		disconnect_level()
		level = val
		connect_level()

func _ready() -> void:
	collision.disable_mode = CollisionObject2D.DISABLE_MODE_REMOVE
	if not Global.in_editor:
		key_data = key_data.duplicate(true)
	_resolve_collision_mode()
	if hide_shadow:
		shadow.hide()
	collision.area_entered.connect(on_collide)
	update_visual()
	
#	input_grabber.gui_input.connect(_gui_input)
#	input_grabber.mouse_entered.connect(_on_mouse_entered)
#	input_grabber.mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	mouse_entered.emit()
func _on_mouse_exited() -> void:
	mouse_exited.emit()

func disconnect_level() -> void:
	if not is_instance_valid(level): return

func connect_level() -> void:
	if not is_instance_valid(level): return
	_on_changed_glitch_color()

func _on_changed_glitch_color() -> void:
	if not is_instance_valid(key_data): return
	key_data.update_glitch_color(level.logic.glitch_color)
	update_visual()

func _connect_key_data() -> void:
	if not is_instance_valid(key_data): return
	key_data.changed.connect(update_visual)
	update_visual()
	# look... ok?
	show()
	if not is_node_ready(): return
	_resolve_collision_mode()

func _disconnect_key_data() -> void:
	if is_instance_valid(key_data):
		key_data.changed.disconnect(update_visual)

func _process(_delta: float) -> void:
	if key_data.color in [Enums.colors.master, Enums.colors.pure]:
		var frame := floori(Global.time / Rendering.SPECIAL_ANIM_DURATION) % 4
		if frame == 3:
			frame = 1
		special.frame = (special.frame % 4) + frame * 4

func _resolve_collision_mode() -> void:
	if not is_instance_valid(level) or key_data.is_spent:
		collision.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		collision.process_mode = Node.PROCESS_MODE_INHERIT

func set_special_texture(color: Enums.colors) -> void:
	match color:
		Enums.colors.stone:
			special.texture = preload("res://level_elements/keys/spr_key_stone.png")
			special.vframes = 2
		Enums.colors.master:
			special.texture = preload("res://level_elements/keys/spr_key_master.png")
			special.vframes = 4
		Enums.colors.pure:
			special.texture = preload("res://level_elements/keys/spr_key_pure.png")
			special.vframes = 4

func update_visual() -> void:
	if not is_node_ready(): return
	if not is_instance_valid(key_data): return
	if not ignore_position: position = key_data.position
	fill.hide()
	outline.hide()
	special.hide()
	glitch.hide()
	number.hide()
	symbol.hide()
	symbol_inf.hide()
	# get the outline / shadow / fill
	var spr_frame = {
		Enums.key_types.exact: 1,
		Enums.key_types.star: 2,
		Enums.key_types.unstar: 3,
	}.get(key_data.type)
	if spr_frame == null: spr_frame = 0
	shadow.frame = spr_frame
	fill.frame = spr_frame
	outline.frame = spr_frame
	special.frame = spr_frame
	glitch.frame = spr_frame
	symbol_inf.visible = key_data.is_infinite
	if key_data.color == Enums.colors.master and key_data.type == Enums.key_types.add:
		shadow.frame = 4
	if key_data.color in [Enums.colors.master, Enums.colors.pure, Enums.colors.stone]:
		special.show()
		set_special_texture(key_data.color)
	elif key_data.color == Enums.colors.glitch:
		glitch.show()
		if is_instance_valid(level) and level.logic.glitch_color != Enums.colors.glitch:
			if level.logic.glitch_color in [Enums.colors.master, Enums.colors.pure, Enums.colors.stone]:
				special.show()
				set_special_texture(level.logic.glitch_color)
				special.frame = special.frame % 4 + 4 * (special.vframes - 1)
			else:
				fill.show()
				fill.frame = fill.frame % 4 + 4
				fill.modulate = Rendering.key_colors[level.logic.glitch_color]
	else:
		fill.show()
		outline.show()
		fill.modulate = Rendering.key_colors[key_data.color]
	
	
	# draw the number
	if key_data.type == Enums.key_types.add or key_data.type == Enums.key_types.exact:
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
			Enums.key_types.flip: 0,
			Enums.key_types.rotor: 1,
			Enums.key_types.rotor_flip: 2,
		}.get(key_data.type)
		if frame != null:
			symbol.frame = frame
			symbol.show()

func on_collide(_who: Node2D) -> void:
	if key_data.is_spent:
		print("is spent so nvm")
		return
	on_pickup()

func get_mouseover_text() -> String:
	return key_data.get_mouseover_text()

func undo() -> void:
	# HACK: fix for undoing at the same time that key is picked up making the key be picked up again after undoing
	await get_tree().physics_frame
	show()
	key_data.is_spent = false
	_resolve_collision_mode()
	for area in collision.get_overlapping_areas():
		on_collide(area)

func redo() -> void:
	if not key_data.is_infinite:
		key_data.is_spent = true
	_resolve_collision_mode()
	hide()

func on_pickup() -> void:
	level.logic.pick_up_key(self)
	
	
	picked_up.emit()
	
	snd_pickup.pitch_scale = 1
	if key_data.color == Enums.colors.master:
		snd_pickup.stream = preload("res://level_elements/keys/master_pickup.wav")
		if key_data.amount.is_negative():
			snd_pickup.pitch_scale = 0.82
	elif key_data.type in [Enums.key_types.flip, Enums.key_types.rotor, Enums.key_types.rotor_flip]:
		snd_pickup.stream = preload("res://level_elements/keys/signflip_pickup.wav")
	elif key_data.type == Enums.key_types.star:
		snd_pickup.stream = preload("res://level_elements/keys/star_pickup.wav")
	elif key_data.type == Enums.key_types.unstar:
		snd_pickup.stream = preload("res://level_elements/keys/unstar_pickup.wav")
	elif key_data.amount.is_negative():
		snd_pickup.stream = preload("res://level_elements/keys/negative_pickup.wav")
	else:
		snd_pickup.stream = preload("res://level_elements/keys/key_pickup.wav")
	snd_pickup.play()

#func get_rect() -> Rect2:
#	return input_grabber.get_global_rect()
