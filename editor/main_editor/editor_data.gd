extends RefCounted
class_name EditorData

signal changed_level_pack_data
var level_pack_data: LevelPackData:
	set = set_level_pack_data

var pack_state: LevelPackStateData:
	set = set_pack_state

signal changed_level_data
func emit_changed_level_data():
	changed_level_data.emit()

var level_data: LevelData:
	get:
		return pack_state.get_current_level()
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
var level_pack_properties_editor: LevelPackPropertiesEditor
var entry_editor: EntryEditor
var salvage_point_editor: SalvagePointEditor
var level_element_editors: Dictionary = {}

# what's currently being edited
# (not an enum because it's easier to check "if editor_data.doors" than like, "if editor_data.currently_editing == EditorData.Editing.DOORS"... or whatever using enums would look like)
# I guess I could always use an enum internally and expose functions like is_editing_doors(), but, eh.
var tab_is_tilemap_edit := false
var is_placing_level_element := false
var level_element_type: Enums.level_element_types = Enums.level_element_types.door
var tab_is_level_properties := false
var tab_is_editing_settings := false
var tab_is_multiple_selection := false
var is_placing_player_spawn := false
var is_placing_goal_position := false

var _setting_pack_and_state := false
func set_pack_and_state(pack: LevelPackData, state: LevelPackStateData) -> void:
	assert(state.pack_data == pack)
	_setting_pack_and_state = true
	level_pack_data = pack
	pack_state = state
	_setting_pack_and_state = false
	if gameplay:
		gameplay.load_level_pack(level_pack_data, pack_state)
	changed_level_pack_data.emit()

func set_level_pack_data(pack: LevelPackData) -> void:
	if level_pack_data == pack: return
	level_pack_data = pack
	Global.settings.current_editor_pack = level_pack_data.file_path
	if not _setting_pack_and_state:
		assert(pack_state.pack_data == level_pack_data)
		changed_level_pack_data.emit()

func set_pack_state(state: LevelPackStateData) -> void:
	if state == pack_state: return
	if pack_state:
		pack_state.changed_current_level.disconnect(emit_changed_level_data)
	pack_state = state
	if pack_state:
		pack_state.changed_current_level.connect(emit_changed_level_data)
	if not _setting_pack_and_state:
		changed_level_pack_data.emit()

func _update_current_level_data() -> void:
	
	pass

static func new_with_defaults() -> EditorData:
	var data := EditorData.new()
	var pack := LevelPackData.get_default_level_pack()
	var state := LevelPackStateData.make_from_pack_data(pack)
	data.set_pack_and_state(pack, state)
	return data
