@tool
extends MarginContainer
class_name EntryEditor

# set externally
var editor_data: EditorData:
	set(val):
		assert(not editor_data)
		editor_data = val
		editor_data.changed_level_pack_data.connect(_on_changed_level_pack_data)
		_on_changed_level_pack_data()

@export var data: EntryData:
	set(val):
		data = val
		if not is_node_ready(): return
		# TODO: Allow editing entries in the level (currently not done to be consistent with door editing)
		entry.data = data
		_set_to_data()
@onready var entry: Entry = %Entry
@onready var level_name: Label = %LevelName
@onready var level_list: LevelList = %LevelList

func _set_to_data() -> void:
	level_list.set_selected_to(data.leads_to)
	_update_level_name()

func _ready() -> void:
	visibility_changed.connect(_general_update)
	level_list.selected_level.connect(_update_leads_to)

func _general_update() -> void:
	if not visible: return
	if not editor_data: return
	_update_level_name()

func _update_leads_to(id: int) -> void:
	data.leads_to = id - 1
	_update_level_name()

func _update_level_name() -> void:
	if not editor_data: return
	var level := editor_data.level_pack_data.levels[data.leads_to]
	level_name.text = level.title + "\n" + level.name

func _on_changed_level_pack_data() -> void:
	level_list.pack_data = editor_data.level_pack_data
	data.leads_to = 0
	_set_to_data()
	_general_update()
