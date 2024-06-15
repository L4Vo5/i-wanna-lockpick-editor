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
@onready var nine_patch_rect: NinePatchRect = %NinePatchRect

var base_offset: Vector2
func _ready() -> void:
	base_offset = nine_patch_rect.position
	generate_keys()
	Global.changed_is_playing.connect(func():
		if not Global.is_playing:
			hide_keypad()
		elif Input.is_action_pressed("keypad"):
			show_keypad()
		)

func _unhandled_key_input(event: InputEvent) -> void:
	if not Global.is_playing:
		return
	if event.is_action("keypad") and not event.is_echo():
		if event.is_pressed():
			show_keypad()
		else:
			hide_keypad()
		get_tree().root.set_input_as_handled()

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
			var key: Key = KEY.instantiate()
			key.position = pos
			key.data = KeyData.new()
			key.data.color = KEY_COLORS[y * 2 + x]
			key.data.amount = ComplexNumber.new_with(1, 0)
			key.data.type = Enums.key_types.add
			key.hide_shadow = true
			key.ignore_position = true
			keys.add_child(key)


func update_pos() -> void:
		if is_instance_valid(Global.current_level):
			nine_patch_rect.global_position = Global.current_level.global_position + base_offset
			if Global.in_level_editor:
				nine_patch_rect.global_position += Global.current_level.get_viewport().get_parent().global_position
