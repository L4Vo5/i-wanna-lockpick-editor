extends Control
class_name KeyPad

const KEY := preload("res://rendering/keys/key.tscn")
const KEY_START := Vector2i(20, 20)
const KEY_DIFF := Vector2i(204, 68) - KEY_START
const KEY_COLORS := [
	Enums.color.white, Enums.color.master,
	Enums.color.orange, Enums.color.pure,
	Enums.color.purple, Enums.color.brown,
	Enums.color.pink, Enums.color.red,
	Enums.color.cyan, Enums.color.green,
	Enums.color.black, Enums.color.blue,
	Enums.color.stone, Enums.color.glitch
]
@onready var keys: Node2D = %Keys

func _ready() -> void:
	generate_keys()

func _process(delta: float) -> void:
	visible = Input.is_action_pressed("keypad")

func generate_keys() -> void:
	for child in keys.get_children():
		child.queue_free()
	for y in 7:
		for x in 2:
			var pos := KEY_START + KEY_DIFF * Vector2i(x, y)
			var key: Key = KEY.instantiate()
			key.position = pos
			# make unique
			key.key_data = key.key_data.duplicate(true)
			key.key_data.color = KEY_COLORS[y * 2 + x]
			key.in_keypad = true
			keys.add_child(key)


