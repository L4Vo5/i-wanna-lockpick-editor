extends Area2D

@export var key_data: KeyData

@onready var spr_fill: Sprite2D = %Fill
@onready var snd_pickup: AudioStreamPlayer = %Pickup

func _ready() -> void:
	body_entered.connect(on_collide)

func on_collide(_who: Node2D) -> void:
	if key_data.spent[0]: return
	on_pickup()

func on_pickup() -> void:
	if Global.print_actions:
		print("Picked up a key")
	key_data.spent[0] = true
	match key_data.type:
		key_data.key_types.real:
			Global.current_level.key_counts[key_data.color].real_part += key_data.amount
		key_data.key_types.imaginary:
			Global.current_level.key_counts[key_data.color].imaginary_part += key_data.amount
		key_data.key_types.rotor:
			Global.current_level.key_counts[key_data.color].rotor()
		key_data.key_types.flip:
			Global.current_level.key_counts[key_data.color].flip()
		key_data.key_types.rotor_flip:
			Global.current_level.key_counts[key_data.color].rotor().flip()
	hide()
	snd_pickup.play()
