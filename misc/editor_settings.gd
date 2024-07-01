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

## Editor State is stuff that's always handled automatically, it doesn't show up in the settings editor. (at least, that sounds like a good idea)
@export_group("EditorState")

@export var current_editor_tab := 0:
	set(val):
		current_editor_tab = val
		queue_save()

@export var current_editor_pack := "":
	set(val):
		current_editor_pack = val
		queue_save()

# TODO: instead, store the level by level pack in a huge dict?
## Since this is a potentially user-facing setting, it's 1-indexed.
@export var current_editor_level_id := 1:
	set(val):
		current_editor_level_id = val
		queue_save()

const PATH := "user://settings.cfg"
var _config_file := ConfigFile.new()

# [variable_name, section]
var saved_variables := []

func _init() -> void:
	# Collect all the variables we want to save
	var current_section := ""
	for property in get_property_list():
		var usage_bitmask := PROPERTY_USAGE_SCRIPT_VARIABLE | PROPERTY_USAGE_STORAGE
		if property.usage & usage_bitmask == usage_bitmask:
			saved_variables.push_back([property.name, current_section])
		elif property.usage & PROPERTY_USAGE_GROUP:
			current_section = property.name
	# Open the existing config file, if it exists.
	var err := _config_file.load(PATH)
	if err != OK:
		return
	# Set all the variables to their saved names.
	for arr in saved_variables:
		var variable_name = arr[0]
		var section = arr[1]
		if _config_file.has_section_key(section, variable_name):
			set(variable_name, _config_file.get_value(section, variable_name))

var is_changed_queued := false
func queue_emit_changed() -> void:
	if not is_changed_queued:
		is_changed_queued = true
		_emit_changed.call_deferred()

func _emit_changed() -> void:
	changed.emit()
	is_changed_queued = false

## Currently called by Global before the game is closed.
func on_exit() -> void:
	if is_save_queued:
		_save()

var is_save_queued := false
var last_save_time := -999999
## Save every 10 seconds at most, to not uselessly write files.
const SAVE_EVERY := 10.0
func queue_save() -> void:
	if not is_save_queued:
		is_save_queued = true
		var time_since_last_save := (Time.get_ticks_msec() - last_save_time) / 1000.0
		if time_since_last_save < SAVE_EVERY:
			await Engine.get_main_loop().create_timer(SAVE_EVERY - time_since_last_save).timeout
		_save.call_deferred()

func _save() -> void:
	last_save_time = Time.get_ticks_msec()
	for arr in saved_variables:
		var variable_name = arr[0]
		var section = arr[1]
		_config_file.set_value(section, variable_name, get(variable_name))
	
	_config_file.save(PATH)
	is_save_queued = false

