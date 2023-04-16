extends MarginContainer
class_name LevelPropertiesEditor

# TODO: Update properly when editor_data.level_data changes
var editor_data: EditorData:
	set(val):
		if editor_data == val: return
		editor_data = val
		if is_instance_valid(editor_data):
			_level_data = editor_data.level_data

var _level_data: LevelData:
	set(val):
		if _level_data == val: return
		_disconnect_level_data()
		_level_data = val
		_connect_level_data()

@onready var player_spawn_coord: Label = %PlayerSpawnCoord

func _connect_level_data() -> void:
	if not is_instance_valid(_level_data): return
	_level_data.changed_player_spawn_position.connect(_on_changed_player_spawn_pos)
	_on_changed_player_spawn_pos()

func _disconnect_level_data() -> void:
	if not is_instance_valid(_level_data): return
	_level_data.changed_player_spawn_position.disconnect(_on_changed_player_spawn_pos)

func _on_changed_player_spawn_pos() -> void:
	if not is_ready: return
	if not is_instance_valid(_level_data): return
	player_spawn_coord.text = str(_level_data.player_spawn_position)

var is_ready := false
func _ready() -> void:
	is_ready = true
	_on_changed_player_spawn_pos()
