extends RefCounted
class_name LockpickEditorSettings

var should_save_on_play := true:
	set(val):
		should_save_on_play = val
		_config_file.set_value("", "ShouldSaveOnPlay", val)
		save()

var sound_volume := 1.0:
	set(val):
		sound_volume = val
		var idx := AudioServer.get_bus_index(&"Sfx")
		assert(idx != -1)
		var db := linear_to_db(val)
		AudioServer.set_bus_volume_db(idx, db)
		_config_file.set_value("", "SoundVolume", val)
		save()

const PATH := "user://editor_settings.cfg"
var _config_file := ConfigFile.new()

func _init() -> void:
	var err := _config_file.load(PATH)
	if err != OK:
		return
	should_save_on_play = _config_file.get_value("", "ShouldSaveOnPlay", true)
	sound_volume = _config_file.get_value("", "SoundVolume", 1.0)

func save() -> void:
	_config_file.save(PATH)

