@tool
extends Control
class_name KeyPad

const KEY := preload("res://level_elements/keys/key.tscn")
const KEY_START := Vector2i(20, 20)
const KEY_DIFF := Vector2i(204, 68) - KEY_START
const KEY_COLORS := [
	Enums.Colors.White, Enums.Colors.Master,
	Enums.Colors.Orange, Enums.Colors.Pure,
	Enums.Colors.Purple, Enums.Colors.Brown,
	Enums.Colors.Pink, Enums.Colors.Red,
	Enums.Colors.Cyan, Enums.Colors.Green,
	Enums.Colors.Black, Enums.Colors.Blue,
	Enums.Colors.Stone, Enums.Colors.Glitch
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
			key.data.type = Enums.KeyTypes.Add
			key.hide_shadow = true
			key.ignore_position = true
			keys.add_child(key)
