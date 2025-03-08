@tool
extends Control
# Shouldn't call it Key because there's a global enum called Key!
class_name CounterPart
## Key lol

@export var data: CounterPartData:
	set(val):
		if data == val: return
		_disconnect_data()
		data = val
		_connect_data()

@onready var fill: Sprite2D = %Fill
@onready var outline: Sprite2D = %Outline
@onready var star: Sprite2D = %Star
@onready var special: Sprite2D = %Special
@onready var glitch: Sprite2D = %SprGlitch

@onready var text: Label = %Amount

var level: Level = null:
	set(val):
		if level == val: return
		disconnect_level()
		level = val
		connect_level()

func _ready() -> void:
	update_visual()

func disconnect_level() -> void:
	if not is_instance_valid(level): return

func connect_level() -> void:
	if not is_instance_valid(level): return

func _connect_data() -> void:
	if not is_instance_valid(data): return
	data.changed.connect(update_visual)
	update_visual()
	# look... ok?
	show()

func _disconnect_data() -> void:
	if is_instance_valid(data):
		data.changed.disconnect(update_visual)

func _process(_delta: float) -> void:
	if !data: return
	if data.color in [Enums.Colors.Master, Enums.Colors.Pure]:
		var frame := floori(Global.time / Rendering.SPECIAL_ANIM_DURATION) % 4
		if frame == 3:
			frame = 1
		special.frame = (special.frame % 4) + frame * 4
	update_visual()

func set_special_texture(color: Enums.Colors) -> void:
	match color:
		Enums.Colors.Stone:
			special.texture = preload("res://level_elements/keys/spr_key_stone.png")
			special.vframes = 2
		Enums.Colors.Master:
			special.texture = preload("res://level_elements/keys/spr_key_master.png")
			special.vframes = 4
		Enums.Colors.Pure:
			special.texture = preload("res://level_elements/keys/spr_key_pure.png")
			special.vframes = 4

func update_visual() -> void:
	if not is_node_ready(): return
	if not is_instance_valid(data): return
	fill.hide()
	outline.hide()
	special.hide()
	glitch.hide()
	star.hide()
	if data.color in [Enums.Colors.Master, Enums.Colors.Pure, Enums.Colors.Stone]:
		special.show()
		set_special_texture(data.color)
	elif data.color == Enums.Colors.Glitch:
		glitch.show()
		if is_instance_valid(level) and level.logic.glitch_color != Enums.Colors.Glitch:
			if level.logic.glitch_color in [Enums.Colors.Master, Enums.Colors.Pure, Enums.Colors.Stone]:
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
		fill.modulate = Rendering.key_colors[data.color]
	
	#set_position(Vector2(16, 17 + 49 * data.position))
	star.rotation_degrees += 1.1
	
	if level:
		text.text = "x " + str(level.logic.key_counts[data.color])
		if level.logic.star_keys[data.color]:
			star.show()
	else:
		text.text = "x 0"
