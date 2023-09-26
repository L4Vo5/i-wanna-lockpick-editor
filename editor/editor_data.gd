extends RefCounted
class_name EditorData

signal changed_level_data

var level_data: LevelData:
	set(val):
		if level_data == val: return
		_disconnect_connect_level_data()
		level_data = val
		_connect_level_data()
		changed_level_data.emit()

signal changed_is_playing
var is_playing := false:
	set(val):
		if is_playing == val: return
		is_playing = val
		changed_is_playing.emit()
var disable_editing := false

var level: Level
var door_editor: DoorEditor
var key_editor: KeyEditor
var tile_editor: MarginContainer
var side_tabs: TabContainer
var entry_editor: EntryEditor

# what's currently being edited
var tilemap_edit := false
var objects := false
var doors := false
var keys := false
var level_properties := false
var player_spawn := false
var goal_position := false
var entries := false

# object selection / dragging / highlight / etc
# note that hover_highlight is part of the level

var hover_highlight: HoverHighlight
var danger_highlight: HoverHighlight
var selected_highlight: HoverHighlight


###

func _connect_level_data() -> void:
	if not is_instance_valid(level_data): return
	Global.current_level.level_data = level_data

func _disconnect_connect_level_data() -> void:
	if not is_instance_valid(level_data): return
