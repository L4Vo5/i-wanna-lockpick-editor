@tool
extends Control
class_name KeyPad

const KEY := preload("res://level_elements/keys/key.tscn")
const KEY_START := Vector2i(20, 20)
const KEY_DIFF := Vector2i(204, 68) - KEY_START
const KEY_COLORS := [
	Enums.colors.white, Enums.colors.master,
	Enums.colors.orange, Enums.colors.pure,
	Enums.colors.purple, Enums.colors.brown,
	Enums.colors.pink, Enums.colors.red,
	Enums.colors.cyan, Enums.colors.green,
	Enums.colors.black, Enums.colors.blue,
	Enums.colors.stone, Enums.colors.glitch
]
@onready var keys: Node2D = %Keys
@onready var sound: AudioStreamPlayer = %Sound
var level: Level

func _ready() -> void:
	generate_keys()

func show_keypad() -> void:
	if visible: return
	show()
	sound.pitch_scale = 1.5
	sound.play()

func hide_keypad() -> void:
	if not visible: return
	hide()
	sound.pitch_scale = 1
	sound.play()

func generate_keys() -> void:
	for child in keys.get_children():
		child.queue_free()
	for y in 7:
		for x in 2:
			var pos := KEY_START + KEY_DIFF * Vector2i(x, y)
			var key: KeyElement = KEY.instantiate()
			key.position = pos
			key.data = KeyData.new()
			key.data.color = KEY_COLORS[y * 2 + x]
			key.data.amount = ComplexNumber.new_with(1, 0)
			key.data.type = Enums.key_types.add
			key.hide_shadow = true
			key.ignore_position = true
			keys.add_child(key)
