@tool
extends NinePatchRect
class_name WarpRod

@onready var sound: AudioStreamPlayer = %Sound
const NODE_AVAILABLE = preload("res://level_elements/ui/warp_rod/node_available.png")
const NODE_CURRENT = preload("res://level_elements/ui/warp_rod/node_current.png")
const NODE_OUTLINE = preload("res://level_elements/ui/warp_rod/node_outline.png")
const NODE_UNAVAILABLE = preload("res://level_elements/ui/warp_rod/node_unavailable.png")

func _ready() -> void:
	# Kinda useless to do it this way but just making sure.
	var margin_container: MarginContainer = $MarginContainer as MarginContainer
	margin_container.add_theme_constant_override("margin_top", patch_margin_top)
	margin_container.add_theme_constant_override("margin_bottom", patch_margin_bottom)
	margin_container.add_theme_constant_override("margin_left", patch_margin_left)
	margin_container.add_theme_constant_override("margin_right", patch_margin_right)

func show_warp_rod() -> void:
	show()
	sound.pitch_scale = 1.5
	sound.play()

func hide_warp_rod() -> void:
	hide()
	sound.pitch_scale = 1
	sound.play()
