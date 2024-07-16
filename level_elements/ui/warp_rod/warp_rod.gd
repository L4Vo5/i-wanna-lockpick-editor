extends Control
class_name WarpRod

@onready var sound: AudioStreamPlayer = %Sound

func show_warp_rod() -> void:
	show()
	sound.pitch_scale = 1.5
	sound.play()

func hide_warp_rod() -> void:
	hide()
	sound.pitch_scale = 1
	sound.play()
