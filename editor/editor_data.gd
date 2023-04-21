extends RefCounted
class_name EditorData

signal changed_level_data
signal changed_level_path

var level_data: LevelData:
	set(val):
		if level_data == val: return
		_disconnect_connect_level_data()
		level_data = val
		_connect_level_data()
		changed_level_data.emit()

var is_playing := false
var disable_editing := false

var door_editor: DoorEditor
var key_editor: KeyEditor

# what's currently being edited
var tilemap_edit := false
var objects := false
var doors := false
var keys := false
var level_properties := false


###

func _connect_level_data() -> void:
	if not is_instance_valid(level_data): return
	level_data.changed.connect(_check_level_path)
	
	_check_level_path()
	Global.current_level.level_data = level_data

func _disconnect_connect_level_data() -> void:
	if not is_instance_valid(level_data): return
	level_data.changed.disconnect(_check_level_path)

var _level_path: String
func _check_level_path() -> void:
	if level_data.resource_path == _level_path: return
	_level_path = level_data.resource_path
	changed_level_path.emit()
