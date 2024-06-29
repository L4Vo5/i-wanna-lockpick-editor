extends RefCounted
class_name LockpickSettings

signal changed

@export var should_save_on_play := true:
	set(val):
		should_save_on_play = val
		queue_emit_changed()
		queue_save()

@export var sound_volume := 1.0:
	set(val):
		sound_volume = val
		var idx := AudioServer.get_bus_index(&"Sfx")
		assert(idx != -1)
		var db := linear_to_db(val)
		AudioServer.set_bus_volume_db(idx, db)
		queue_emit_changed()
		queue_save()

@export var is_autorun_on := false:
	set(val):
		is_autorun_on = val
		queue_emit_changed()
		queue_save()

const PATH := "user://settings.cfg"
var _config_file := ConfigFile.new()

var saved_variables: PackedStringArray = []
func _init() -> void:
	# Collect all the variables we want to save
	for property in get_property_list():
		var usage_bitmask := PROPERTY_USAGE_SCRIPT_VARIABLE | PROPERTY_USAGE_STORAGE
		if property.usage & usage_bitmask == usage_bitmask:
			saved_variables.push_back(property.name)
	# Open the existing config file, if it exists.
	var err := _config_file.load(PATH)
	if err != OK:
		return
	# Set all the variables to their saved names.
	for variable_name in saved_variables:
		if _config_file.has_section_key("", variable_name):
			set(variable_name, _config_file.get_value("", variable_name))

var is_changed_queued := false
func queue_emit_changed() -> void:
	if not is_changed_queued:
		is_changed_queued = true
		_emit_changed.call_deferred()

func _emit_changed() -> void:
	changed.emit()
	is_changed_queued = false

var is_save_queued := false
func queue_save() -> void:
	if not is_save_queued:
		is_save_queued = true
		_save.call_deferred()

func _save() -> void:
	for variable_name in saved_variables:
		_config_file.set_value("", variable_name, get(variable_name))
	
	_config_file.save(PATH)
	is_save_queued = false

