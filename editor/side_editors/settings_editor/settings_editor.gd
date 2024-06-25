extends MarginContainer

@onready var save_on_play: CheckBox = %SaveOnPlay

func _ready() -> void:
	save_on_play.button_pressed = Global.editor_settings.should_save_on_play
	save_on_play.toggled.connect(_on_save_on_play_toggled)
	save_on_play.tooltip_text = "Save the level automatically before playing it"

func _on_save_on_play_toggled(is_toggled: bool) -> void:
	Global.editor_settings.should_save_on_play = is_toggled
