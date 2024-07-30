extends CanvasLayer
class_name LevelUI

@onready var level: Level = get_parent()
@onready var key_pad: KeyPad = $KeyPad
@onready var warp_rod: WarpRod = $WarpRod
@onready var autorun_sound: AudioStreamPlayer = %Autorun
@onready var autorun_off: Sprite2D = %AutorunOff
@onready var autorun_on: Sprite2D = %AutorunOn
@onready var darken_background: ColorRect = %DarkenBackground
var currently_shown: CanvasItem:
	set(val):
		currently_shown = val
		darken_background.visible = is_instance_valid(currently_shown)

func _init() -> void:
	visibility_changed.connect(_on_visibility_changed)

func _ready() -> void:
	assert(level)
	key_pad.level = level
	(func():
		warp_rod.gameplay_manager = level.gameplay_manager
	).call_deferred()

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
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

func _on_visibility_changed() -> void:
	if not visible:
		if currently_shown == warp_rod:
			warp_rod.hide_warp_rod()
		elif currently_shown == key_pad:
			key_pad.hide_keypad()
		currently_shown = null
		if is_instance_valid(autorun_tween):
			autorun_tween.kill()
			autorun_on.hide()
			autorun_off.hide()

var autorun_tween: Tween
func show_autorun_animation(is_autorun_on: bool) -> void:
	var used: Sprite2D
	if is_autorun_on:
		autorun_sound.pitch_scale = 1
		autorun_off.hide()
		used = autorun_on
	else:
		autorun_sound.pitch_scale = 0.7
		autorun_on.hide()
		used = autorun_off
	autorun_sound.play()
	
	if is_instance_valid(autorun_tween):
		autorun_tween.kill()
	autorun_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	used.show()
	used.modulate.a = 0
	
	autorun_tween.tween_property(used, "modulate:a", 1, 0.1)
	autorun_tween.tween_interval(0.5)
	autorun_tween.tween_property(used, "modulate:a", 0, 0.5)

func autorun_off_animation() -> void:
	pass
