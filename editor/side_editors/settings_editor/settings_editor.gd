extends MarginContainer

@onready var save_on_play: CheckBox = %SaveOnPlay
@onready var sound_slider: HSlider = %SoundSlider
@onready var cacophony: CheckButton = %Cacophony
@onready var autorun: CheckBox = %Autorun

var settings: LockpickSettings:
	get:
		return Global.settings

var all_sounds: Array[AudioStream] = []
func _ready() -> void:
	save_on_play.tooltip_text = "Save the level automatically before playing it"
	
	settings.changed.connect(set_to_current_settings)
	set_to_current_settings()
	
	autorun.toggled.connect(_on_autorun_toggled)
	save_on_play.toggled.connect(_on_save_on_play_toggled)
	sound_slider.value_changed.connect(_on_sound_slider_value_changed)
	cacophony.toggled.connect(_on_cacophony_toggled)


func set_to_current_settings() -> void:
	save_on_play.button_pressed = settings.should_save_on_play
	sound_slider.value = settings.sound_volume
	autorun.button_pressed = settings.is_autorun_on

func _on_save_on_play_toggled(is_toggled: bool) -> void:
	settings.should_save_on_play = is_toggled

func _on_sound_slider_value_changed(value: float) -> void:
	settings.sound_volume = value

func _on_autorun_toggled(is_toggled: bool) -> void:
	settings.is_autorun_on = is_toggled

func _on_cacophony_toggled(toggled_on: bool) -> void:
	if not toggled_on:
		for child in cacophony.get_children():
			cacophony.remove_child(child)
	else:
		if all_sounds.is_empty():
			load_all_sounds()
		if all_sounds.is_empty():
			cacophony.hide()
			return
		assert(AudioServer.get_bus_index(&"Sfx") != -1)
		for _i in 8:
			var node := AudioStreamPlayer.new()
			node.bus = &"Sfx"
			cacophony.add_child(node)
			node.stream = all_sounds[randi() % all_sounds.size()]
			node.play()
			node.finished.connect(func():
				node.stream = all_sounds[randi() % all_sounds.size()]
				node.play()
			)

func load_all_sounds() -> void:
	var dirs := ["res://"]
	while not dirs.is_empty():
		var dir: String = dirs.pop_back() as String
		for new_dir in DirAccess.get_directories_at(dir):
			dirs.push_back(dir.path_join(new_dir))
		for file_name in DirAccess.get_files_at(dir):
			# WAITING4GODOT: ...really...?
			if file_name.get_extension() in ["wav", "sample"]:
				var sound = load(dir.path_join(file_name))
				all_sounds.push_back(sound)
