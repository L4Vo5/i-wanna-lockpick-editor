extends RefCounted
class_name EditorData

signal changed_level_pack_data
var level_pack_data: LevelPackData:
	set(val):
		if level_pack_data == val: return
		level_pack_data = val
		gameplay.pack_data = val
		Global.settings.current_editor_pack = level_pack_data.file_path
		changed_level_pack_data.emit()

var pack_state_data: LevelPackStateData:
	get:
		return gameplay.pack_state if gameplay else null

signal changed_level_data
func emit_changed_level_data():
	Global.settings.current_editor_level_id = pack_state_data.current_level + 1
	changed_level_data.emit()
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

var gameplay: GameplayManager
var level: Level:
	set(val):
		if level:
			level.changed_level_data.disconnect(emit_changed_level_data)
		level = val
		if level:
			level.changed_level_data.connect(emit_changed_level_data)
var door_editor: DoorEditor
var key_editor: KeyEditor
var tile_editor: MarginContainer
var side_tabs: BookmarkTabContainer
var level_properties_editor: LevelPropertiesEditor
var entry_editor: EntryEditor
var salvage_point_editor: SalvagePointEditor
var level_element_editors: Dictionary = {}

# what's currently being edited
# (not an enum because it's easier to check "if editor_data.doors" than like, "if editor_data.currently_editing == EditorData.Editing.DOORS"... or whatever using enums would look like)
# I guess I could always use an enum internally and expose functions like is_editing_doors(), but, eh.
var tilemap_edit := false
var level_elements := false
var level_element_type: Enums.level_element_types = Enums.level_element_types.door
var level_properties := false
var player_spawn := false
var goal_position := false
var editing_settings := false

# object selection / dragging / highlight / etc
# note that hover_highlight is part of the level

var hover_highlight: HoverHighlight
var danger_highlight: HoverHighlight
var selected_highlight: HoverHighlight
