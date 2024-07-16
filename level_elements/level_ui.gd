extends CanvasLayer

var level: Level:
	get:
		return get_parent()
@onready var key_pad: KeyPad = $KeyPad
@onready var warp_rod: WarpRod = $WarpRod
var currently_shown: CanvasItem

func _unhandled_key_input(event: InputEvent) -> void:
	if not Global.is_playing:
		return
	if event.is_echo():
		return
	if event.is_action(&"keypad"):
		if event.is_pressed() and currently_shown == null:
			currently_shown = key_pad
			key_pad.show_keypad()
		elif event.is_released() and currently_shown == key_pad:
			currently_shown = null
			key_pad.hide_keypad()
		get_tree().root.set_input_as_handled()
	if event.is_action(&"warp_rod"):
		if event.is_pressed():
			if currently_shown == warp_rod:
				warp_rod.hide_warp_rod()
				currently_shown = null
			elif currently_shown == null:
				warp_rod.show_warp_rod()
				currently_shown = warp_rod
		get_tree().root.set_input_as_handled()
