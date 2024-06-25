extends RefCounted
class_name LockpickEditorSettings

var should_save_on_play := true:
	set(val):
		should_save_on_play = val
		_config_file.set_value("", "ShouldSaveOnPlay", val)
		save()

const PATH := "user://editor_settings.cfg"
var _config_file := ConfigFile.new()

func _init() -> void:
	var err := _config_file.load(PATH)
	if err != OK:
		return
	should_save_on_play = _config_file.get_value("", "ShouldSaveOnPlay", true)

func save() -> void:
	_config_file.save(PATH)

