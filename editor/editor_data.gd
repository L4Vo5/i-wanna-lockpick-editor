extends RefCounted
class_name EditorData

signal changed_level_pack_data
var level_pack_data: LevelPackData:
	set(val):
		if level_pack_data == val: return
		
		level_pack_data = val
		level.pack_data = val
		changed_level_pack_data.emit()

signal changed_level_data
## Read-only!
var level_data: LevelData:
	get:
		return level.level_data
	set(val):
		assert(false)

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
var level_properties_editor: LevelPropertiesEditor
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
