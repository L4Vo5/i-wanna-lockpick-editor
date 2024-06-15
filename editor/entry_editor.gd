@tool
extends MarginContainer
class_name EntryEditor

# set externally
var editor_data: EditorData:
	set(val):
		if editor_data == val: return
		editor_data = val
		_general_update()

@export var data: EntryData:
	set(val):
		data = val.duplicated()
		if not is_node_ready(): await ready
		# TODO: Allow editing entries in the level (currently not done to be consistent with door editing)
		entry.data = data
		_set_to_data()
@onready var entry: Entry = %Entry
@onready var leads_to: SpinBox = %LeadsTo
@onready var level_name: Label = %LevelName

func _set_to_data() -> void:
	leads_to.value = data.leads_to + 1
	_update_level_name()
	print_debug("adjusting leads_to to %d" % leads_to.value)

func _ready() -> void:
	visibility_changed.connect(_general_update)
	leads_to.value_changed.connect(_update_leads_to.unbind(1))

func _general_update() -> void:
	if !visible: return
	if !editor_data: return
	leads_to.max_value = editor_data.level_pack_data.levels.size()
	_update_level_name()

func _update_leads_to() -> void:
	data.leads_to = leads_to.value as int - 1
	_update_level_name()

func _update_level_name() -> void:
	if !editor_data: return
	var level := editor_data.level_pack_data.levels[data.leads_to]
	level_name.text = level.title + "\n" + level.name
